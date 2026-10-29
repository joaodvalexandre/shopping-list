{{-- The backoffice logo: the app's basket icon, next to the app name.
     Inline styles on purpose: Filament ships a prebuilt stylesheet, so classes of our own are not in it. --}}
<div style="display:flex;align-items:center;gap:0.65rem;">
    <img src="{{ asset('img/logo.svg') }}" alt="" style="width:2.1rem;height:2.1rem;border-radius:0.6rem;flex-shrink:0;">
    <span style="display:flex;flex-direction:column;line-height:1.15;">
        <span style="font-size:1rem;font-weight:600;letter-spacing:-0.01em;">{{ config('app.name') }}</span>
        <span style="font-size:0.65rem;font-weight:500;letter-spacing:0.08em;text-transform:uppercase;opacity:0.6;">{{ __('bo_backoffice') }}</span>
    </span>
</div>
