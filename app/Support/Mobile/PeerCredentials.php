<?php

namespace App\Support\Mobile;

use App\Enums\ListAbility;
use App\Models\ListType;
use App\Models\User;

/**
 * What lets two family phones trust each other with no server in between: a short-lived
 * statement from the server that says who a phone belongs to and what its person may do,
 * signed with the server key (Ed25519) and tied to a key pair that only that phone holds.
 *
 * A phone shows it to a phone nearby together with a proof that it holds the key, so the
 * other one knows the person really is who the statement says (and not simply a family member
 * claiming to be someone with more rights, say one a surprise list is not hidden from).
 */
class PeerCredentials
{
    /** A phone that has been offline for longer than this has to ask the server again. */
    public const VALID_DAYS = 7;

    /**
     * The server signing key, derived from the application key: nothing more to keep safe or
     * back up, and a new application key makes every credential in circulation useless.
     *
     * @return array{public: string, secret: string}
     */
    public static function serverKeys(): array
    {
        $seed = sodium_crypto_generichash('cestou-peer-credentials-v1|' . config('app.key'), '', SODIUM_CRYPTO_SIGN_SEEDBYTES);
        $pair = sodium_crypto_sign_seed_keypair($seed);

        return ['public' => sodium_crypto_sign_publickey($pair), 'secret' => sodium_crypto_sign_secretkey($pair)];
    }

    /**
     * @param  string  $devicePublicKey  the phone's Ed25519 public key, raw bytes
     * @return array{credential: string, signature: string, server_key: string, expires_at: string}
     */
    public static function issue(User $user, string $devicePublicKey): array
    {
        $now = now();
        $expires = $now->copy()->addDays(self::VALID_DAYS);
        $types = ListType::where('family_id', $user->family_id)->orderBy('id')->get();

        // The exact text that is signed is what the phone passes on: no re-encoding to get wrong
        $credential = json_encode([
            'v' => 1,
            'user_id' => $user->id,
            'family_id' => $user->family_id,
            'name' => $user->name,
            'role' => $user->role->value,
            'key' => base64_encode($devicePublicKey),
            'permissions' => $types->mapWithKeys(fn (ListType $type) => [
                $type->id => collect(ListAbility::cases())
                    ->mapWithKeys(fn (ListAbility $ability) => [$ability->value => $user->canOnListType($ability, $type)])
                    ->all(),
            ])->all(),
            'iat' => $now->getTimestamp(),
            'exp' => $expires->getTimestamp(),
        ], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR);

        $keys = self::serverKeys();

        return [
            'credential' => $credential,
            'signature' => base64_encode(sodium_crypto_sign_detached($credential, $keys['secret'])),
            'server_key' => base64_encode($keys['public']),
            'expires_at' => $expires->toIso8601String(),
        ];
    }
}
