{{-- One menu link. $item: MenuItem; $class: classes of the <a>; optional $slot-like $text override --}}
<a href="{{ $item->href() }}"
   @if($item->new_tab) target="_blank" rel="noopener noreferrer" @endif
   class="{{ $class ?? '' }}">{{ $item->labelIn() }}</a>
