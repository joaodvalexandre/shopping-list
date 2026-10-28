<x-filament-widgets::widget>
    <x-filament::section :heading="__('bo_system')" icon="heroicon-o-server-stack" compact>
        {{-- Inline styles on purpose: Filament ships a prebuilt stylesheet, so classes of our own are not in it --}}
        <dl style="margin:0;font-size:0.875rem;">
            @foreach ($this->rows() as $label => $value)
                <div style="display:flex;align-items:center;justify-content:space-between;gap:1rem;padding:0.45rem 0;{{ $loop->last ? '' : 'border-bottom:1px solid rgba(128,128,128,0.18);' }}">
                    <dt style="opacity:0.65;">{{ $label }}</dt>
                    <dd style="margin:0;font-weight:500;">{{ $value }}</dd>
                </div>
            @endforeach
        </dl>
    </x-filament::section>
</x-filament-widgets::widget>
