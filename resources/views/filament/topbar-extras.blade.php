{{-- Next to the user menu: a flag when this is not production, and the language choice.
     Inline styles on purpose: Filament ships a prebuilt stylesheet, so classes of our own are not in it. --}}
<div style="display:flex;align-items:center;gap:0.5rem;">
    @unless (app()->isProduction())
        <x-filament::badge color="warning" size="sm" icon="heroicon-m-exclamation-triangle">
            {{ app()->environment() }}
        </x-filament::badge>
    @endunless

    @php($languages = \App\Models\Language::active())

    @if ($languages->count() > 1)
        <x-filament::dropdown placement="bottom-end">
            <x-slot name="trigger">
                <x-filament::icon-button
                    icon="heroicon-o-language"
                    :label="__('language')"
                    color="gray"
                />
            </x-slot>

            <x-filament::dropdown.list>
                @foreach ($languages as $language)
                    <x-filament::dropdown.list.item
                        tag="a"
                        :href="route('switch-language', $language['code'])"
                        :icon="app()->getLocale() === $language['code'] ? 'heroicon-m-check' : null"
                    >
                        {{ $language['native_name'] }}
                    </x-filament::dropdown.list.item>
                @endforeach
            </x-filament::dropdown.list>
        </x-filament::dropdown>
    @endif
</div>
