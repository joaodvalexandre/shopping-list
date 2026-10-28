<?php

namespace App\Models\Concerns;

use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;

/**
 * Shared by everything the mobile apps sync (lists, items).
 *
 * - a stable `uuid` that devices create offline,
 * - soft deletes, so deletions travel as tombstones,
 * - one `<field>_changed_at` timestamp per synced field, which is what lets
 *   two devices edit different fields of the same row without clobbering
 *   each other (last write wins per field).
 *
 * Models using it declare:  protected array $syncedFields = ['name' => 'name_changed_at'];
 */
trait Syncable
{
    use SoftDeletes;

    public static function bootSyncable(): void
    {
        static::creating(function ($model) {
            $model->uuid ??= (string) Str::uuid();

            // Stamp from the app, not the database default, so precision is the same everywhere
            foreach ($model->syncedFields as $column) {
                $model->{$column} ??= Carbon::now();
            }
        });

        static::saving(function ($model) {
            // Stamp the fields changed through the web app (or anywhere else that
            // did not set the timestamp itself - the sync API sets its own).
            foreach ($model->syncedFields as $field => $column) {
                if ($model->isDirty($field) && ! $model->isDirty($column)) {
                    $model->{$column} = Carbon::now();
                }
            }
        });
    }

    /** ISO-8601 UTC with milliseconds, the format the API speaks. */
    public static function apiTime(?Carbon $time): ?string
    {
        return $time?->copy()->utc()->format('Y-m-d\TH:i:s.v\Z');
    }
}
