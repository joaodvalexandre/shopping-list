<x-app-layout>
    <div class="flex flex-wrap justify-center">
        @if($shoppingList->isEmpty())
            <p class="text-black dark:text-white text-center py-8">{{ __('dashboard_information') }}</p>
        @else
            @foreach ($shoppingList as $item)
                <x-dashboard-block
                    type="shopping_list"
                    model="shopping_list"
                    :data="$item"
                />
            @endforeach
        @endif
    </div>
</x-app-layout>
