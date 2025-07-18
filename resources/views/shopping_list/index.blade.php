<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 dark:text-gray-200 leading-tight">
            {{ __('shopping_list') }}
        </h2>
    </x-slot>

    <div class="py-12">
        <div class="max-w-7xl mx-auto sm:px-6 lg:px-8">
            <div class="bg-white dark:bg-gray-800 overflow-hidden shadow-sm sm:rounded-lg">
                <div class="p-6 text-gray-900 dark:text-gray-100">
                    <div class="flex justify-between items-center mb-6">
                        <h3 class="text-lg font-semibold">{{ __('your_shopping_items') }}</h3>
                        <div>
                            <button id="exportButton" class="bg-green-500 hover:bg-green-600 text-white font-bold py-2 px-4 rounded-full transition duration-300 ease-in-out transform hover:scale-105 mr-2">
                                <i class="fas fa-file-export mr-2"></i>{{ __('export_to_text') }}
                            </button>
                            <a href="{{ route('shopping_list.create') }}" class="bg-blue-500 hover:bg-blue-600 text-white font-bold py-2 px-4 rounded-full transition duration-300 ease-in-out transform hover:scale-105" wire:navigate>
                                <i class="fas fa-plus mr-2"></i>{{ __('add_item') }}
                            </a>
                        </div>
                    </div>

                    @if($shoppingList->isEmpty())
                        <p class="text-gray-500 dark:text-gray-400 text-center py-8">{{ __('no_items_yet') }}</p>
                    @else
                        <div class="overflow-x-auto">
                            <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
                                <thead class="bg-gray-200 dark:bg-gray-600 border-b-2 border-gray-300 dark:border-gray-500">
                                    <tr>
                                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-700 dark:text-gray-200 uppercase tracking-wider">{{ __('name') }}</th>
                                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-700 dark:text-gray-200 uppercase tracking-wider">{{ __('quantity') }}</th>
                                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-700 dark:text-gray-200 uppercase tracking-wider">{{ __('status') }}</th>
                                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-700 dark:text-gray-200 uppercase tracking-wider">{{ __('actions') }}</th>
                                    </tr>
                                </thead>
                                <tbody class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
                                    @foreach($shoppingList as $item)
                                        <tr class="transition duration-150 ease-in-out
                                                   odd:bg-gray-50 even:bg-white
                                                   dark:odd:bg-gray-700 dark:even:bg-gray-800
                                                   hover:bg-gray-100 dark:hover:bg-gray-600">
                                            <td class="px-6 py-4 whitespace-nowrap">{{ $item->name }}</td>
                                            <td class="px-6 py-4 whitespace-nowrap">{{ $item->quantity }}</td>
                                            <td class="px-6 py-4 whitespace-nowrap">
                                                <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full" style="background-color: {{ $item->status->color }}">
                                                    {{ __($item->status->code) }}
                                                </span>
                                            </td>
                                            <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                                                @if($item->status_id === 1) {{-- To Buy --}}
                                                    <form action="{{ route('shopping_list.changeStatus', [$item, 2]) }}" method="POST" class="inline-block">
                                                        @csrf
                                                        @method('PATCH')
                                                        <button type="submit" class="text-blue-600 hover:text-blue-900 dark:text-blue-400 dark:hover:text-blue-600 mr-3">
                                                            <i class="fas fa-shopping-cart mr-1"></i>
                                                        </button>
                                                    </form>
                                                @elseif($item->status_id === 2) {{-- In Cart --}}
                                                    <form action="{{ route('shopping_list.changeStatus', [$item, 3]) }}" method="POST" class="inline-block mr-3">
                                                        @csrf
                                                        @method('PATCH')
                                                        <button type="submit" class="text-green-600 hover:text-green-900 dark:text-green-400 dark:hover:text-green-600">
                                                            <i class="fas fa-check mr-1"></i>
                                                        </button>
                                                    </form>
                                                    <form action="{{ route('shopping_list.changeStatus', [$item, 6]) }}" method="POST" class="inline-block mr-3">
                                                        @csrf
                                                        @method('PATCH')
                                                        <button type="submit" class="text-red-600 hover:text-red-900 dark:text-red-400 dark:hover:text-red-600">
                                                            <i class="fas fa-times mr-1"></i>
                                                        </button>
                                                    </form>
                                                @endif
                                                @if($item->status_id === 1) {{-- Allow edit only for "To Buy" status --}}
                                                    <a href="{{ route('shopping_list.edit', $item) }}" class="text-indigo-600 hover:text-indigo-900 dark:text-indigo-400 dark:hover:text-indigo-600 mr-3" wire:navigate>
                                                        <i class="fas fa-edit mr-1"></i>
                                                    </a>
                                                @endif
                                                <form action="{{ route('shopping_list.destroy', $item) }}" method="POST" class="inline-block">
                                                    @csrf
                                                    @method('DELETE')
                                                    <button type="submit" class="text-red-600 hover:text-red-900 dark:text-red-400 dark:hover:text-red-600" onclick="return confirm('{{ __('confirm_delete') }}')">
                                                        <i class="fas fa-trash-alt mr-1"></i>
                                                    </button>
                                                </form>
                                            </td>
                                        </tr>
                                    @endforeach
                                </tbody>
                            </table>
                        </div>
                    @endif
                </div>
            </div>
        </div>
    </div>
    <script>
        document.getElementById('exportButton').addEventListener('click', function() {
            notificationToggle('exporting_text', 'info');
            fetch('{{ route('shopping_list.export') }}')
                .then(response => response.blob())
                .then(blob => {
                    const url = window.URL.createObjectURL(blob);
                    const a = document.createElement('a');
                    a.style.display = 'none';
                    a.href = url;
                    a.download = 'shopping_list.txt';
                    document.body.appendChild(a);
                    a.click();
                    window.URL.revokeObjectURL(url);
                    notificationToggle('export_success', 'success');
                })
                .catch(() => {
                    notificationToggle('export_error', 'error');
                });
        });
    </script>
</x-app-layout>
