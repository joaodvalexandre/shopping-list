@props([
    'package' => 'mdi',
    'icon', // Only the icon name, e.g., "home"
    'size' => '24',
    'class' => ''
])

<span class="iconify {{ $class }}"
      data-icon="{{$package}}:{{ $icon }}"
      data-width="{{ $size }}"
      data-height="{{ $size }}">
</span>
