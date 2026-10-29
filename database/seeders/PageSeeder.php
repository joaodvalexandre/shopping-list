<?php

namespace Database\Seeders;

use App\Models\Page;
use Illuminate\Database\Seeder;

/**
 * Starter content pages in Portuguese and English. They describe what the app
 * really does, but are a starting point: review them (and add your contact
 * details) in the backoffice before going public. Safe to run again: a page
 * that exists is never overwritten.
 */
class PageSeeder extends Seeder
{
    public function run(): void
    {
        foreach ($this->pages() as $sort => $page) {
            Page::firstOrCreate(['slug' => $page['slug']], $page + ['sort' => $sort + 1]);
        }
    }

    /** @return list<array<string, mixed>> */
    private function pages(): array
    {
        return [
            [
                'slug' => 'about',
                'title' => ['pt' => 'Sobre', 'en' => 'About'],
                'content' => [
                    'pt' => '<p>Esta é uma lista de compras partilhada pela família. Cada família tem as suas próprias listas, e quem gere a família decide o que cada pessoa pode ver e fazer.</p>'
                        . '<h2>Como funciona</h2>'
                        . '<ul><li>As contas são criadas por um administrador: não há registo público.</li>'
                        . '<li>Cada pessoa pode ter permissões diferentes para cada tipo de lista.</li>'
                        . '<li>Uma lista pode ficar escondida de certas pessoas (por exemplo, a lista da festa de anos).</li>'
                        . '<li>Funciona no browser e na aplicação Android.</li></ul>',
                    'en' => '<p>This is a shopping list shared by a family. Every family has its own lists, and whoever manages the family decides what each person can see and do.</p>'
                        . '<h2>How it works</h2>'
                        . '<ul><li>Accounts are created by an administrator: there is no public sign-up.</li>'
                        . '<li>Each person can have different permissions for each type of list.</li>'
                        . '<li>A list can be hidden from certain people (for example, the birthday party list).</li>'
                        . '<li>It works in the browser and in the Android app.</li></ul>',
                ],
                'is_published' => true,
            ],
            [
                'slug' => 'privacy',
                'title' => ['pt' => 'Política de privacidade', 'en' => 'Privacy policy'],
                'content' => [
                    'pt' => '<p>Guardamos o mínimo necessário para a lista funcionar, e não partilhamos os teus dados com ninguém.</p>'
                        . '<h2>Que dados guardamos</h2>'
                        . '<ul><li>O teu nome, email e língua preferida.</li>'
                        . '<li>A tua palavra-passe, guardada de forma cifrada (nunca em texto).</li>'
                        . '<li>As listas e artigos da tua família, e quem os criou ou alterou.</li>'
                        . '<li>Os telemóveis onde tens sessão iniciada e a data do último acesso.</li></ul>'
                        . '<h2>O que não fazemos</h2>'
                        . '<ul><li>Não vendemos nem partilhamos dados com terceiros.</li>'
                        . '<li>Não usamos publicidade nem ferramentas de rastreio.</li></ul>'
                        . '<h2>Quem vê o quê</h2>'
                        . '<p>Só as pessoas da tua família veem as listas da família, e apenas as que as suas permissões permitem. Os administradores da aplicação podem gerir contas, mas não precisam de ler as tuas listas para o fazer.</p>'
                        . '<h2>Apagar os teus dados</h2>'
                        . '<p>Pede ao administrador da tua família para remover a tua conta. Os dados da conta e as sessões nos telemóveis são apagados.</p>',
                    'en' => '<p>We keep the minimum needed for the list to work, and we do not share your data with anyone.</p>'
                        . '<h2>What we keep</h2>'
                        . '<ul><li>Your name, email and preferred language.</li>'
                        . '<li>Your password, stored in scrambled form (never as plain text).</li>'
                        . '<li>Your family\'s lists and items, and who created or changed them.</li>'
                        . '<li>The phones you are signed in on and when you last used them.</li></ul>'
                        . '<h2>What we do not do</h2>'
                        . '<ul><li>We do not sell or share data with third parties.</li>'
                        . '<li>We do not use advertising or tracking tools.</li></ul>'
                        . '<h2>Who sees what</h2>'
                        . '<p>Only the people in your family see the family\'s lists, and only the ones their permissions allow. The application\'s administrators can manage accounts, but do not need to read your lists to do so.</p>'
                        . '<h2>Deleting your data</h2>'
                        . '<p>Ask your family\'s administrator to remove your account. The account data and the sessions on your phones are deleted.</p>',
                ],
                'is_published' => true,
            ],
            [
                'slug' => 'terms',
                'title' => ['pt' => 'Termos de utilização', 'en' => 'Terms of use'],
                'content' => [
                    'pt' => '<p>Ao usares esta aplicação, aceitas o seguinte.</p>'
                        . '<h2>A tua conta</h2>'
                        . '<ul><li>A conta é pessoal. Escolhe uma palavra-passe só tua e não a partilhes.</li>'
                        . '<li>Na primeira vez que entras tens de trocar a palavra-passe temporária.</li></ul>'
                        . '<h2>Uso aceitável</h2>'
                        . '<p>Usa a aplicação para as listas da tua família. Não tentes aceder a dados de outras famílias nem prejudicar o serviço.</p>'
                        . '<h2>Disponibilidade</h2>'
                        . '<p>Fazemos o possível para que o serviço esteja sempre disponível, mas não garantimos que não haja interrupções.</p>',
                    'en' => '<p>By using this application you agree to the following.</p>'
                        . '<h2>Your account</h2>'
                        . '<ul><li>The account is personal. Choose a password of your own and do not share it.</li>'
                        . '<li>The first time you sign in you must replace the temporary password.</li></ul>'
                        . '<h2>Acceptable use</h2>'
                        . '<p>Use the application for your family\'s lists. Do not try to reach other families\' data or harm the service.</p>'
                        . '<h2>Availability</h2>'
                        . '<p>We do our best to keep the service available, but we cannot promise there will be no interruptions.</p>',
                ],
                'is_published' => true,
            ],
        ];
    }
}
