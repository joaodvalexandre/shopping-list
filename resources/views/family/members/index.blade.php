<x-app-layout>
    <div class="flex justify-between items-center">
        <div class="flex gap-2">
            <a href="{{ route('family.members.index') }}" class="px-4 py-2 rounded-full bg-gray-800 text-white dark:bg-gray-200 dark:text-gray-800" wire:navigate>{{ __('members') }}</a>
            <a href="{{ route('family.list-types.index') }}" class="px-4 py-2 rounded-full bg-gray-200 text-gray-800 dark:bg-gray-700 dark:text-gray-200" wire:navigate>{{ __('list_types') }}</a>
        </div>
        <a href="{{ route('family.members.create') }}" class="bg-blue-500 hover:bg-blue-600 text-white font-bold py-2 px-4 rounded-full transition duration-300 ease-in-out transform hover:scale-105" wire:navigate>
            <i class="fas fa-plus mr-2"></i>{{ __('new_member') }}
        </a>
    </div>

    @if(session('temporary_password'))
        <div class="p-4 rounded-lg bg-green-100 text-green-900 dark:bg-green-900 dark:text-green-100">
            <p class="font-semibold">{{ __('temporary_password_notice') }}</p>
            <p class="mt-1">{{ session('temporary_password.email') }}:
                <code class="px-2 py-1 rounded bg-white/60 dark:bg-black/30 select-all">{{ session('temporary_password.password') }}</code>
            </p>
        </div>
    @endif

    @error('member')
        <div class="p-3 rounded-lg bg-red-100 text-red-900 dark:bg-red-900 dark:text-red-100">{{ $message }}</div>
    @enderror

    <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
            <thead class="bg-gray-200 dark:bg-gray-600 border-b-2 border-gray-300 dark:border-gray-500">
                <tr>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-700 dark:text-gray-200 uppercase tracking-wider">{{ __('name') }}</th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-700 dark:text-gray-200 uppercase tracking-wider">{{ __('email') }}</th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-700 dark:text-gray-200 uppercase tracking-wider">{{ __('role') }}</th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-700 dark:text-gray-200 uppercase tracking-wider">{{ __('status') }}</th>
                    <th class="px-6 py-3 w-0 text-left text-xs font-medium text-gray-700 dark:text-gray-200 uppercase tracking-wider">{{ __('actions') }}</th>
                </tr>
            </thead>
            <tbody class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
                @foreach($members as $member)
                    <tr class="odd:bg-gray-50 even:bg-white dark:odd:bg-gray-700 dark:even:bg-gray-800">
                        <td class="px-6 py-4 whitespace-nowrap">{{ $member->name }}</td>
                        <td class="px-6 py-4 whitespace-nowrap">{{ $member->email }}</td>
                        <td class="px-6 py-4 whitespace-nowrap">{{ $member->role->label() }}</td>
                        <td class="px-6 py-4 whitespace-nowrap text-sm">
                            {{ $member->must_change_password ? __('pending_first_login') : __('active') }}
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-right">
                            <div class="flex flex-row gap-2 items-center">
                                <a href="{{ route('family.members.edit', $member) }}"
                                   class="text-yellow-600 hover:text-yellow-900 dark:text-yellow-400 dark:hover:text-yellow-600" wire:navigate>
                                    <x-custom-icon icon="pencil"/>
                                </a>
                                <form method="POST" action="{{ route('family.members.reset_password', $member) }}"
                                      onsubmit="return confirm('{{ __('confirm_reset_password') }}')" class="inline">
                                    @csrf
                                    <button type="submit" class="text-blue-600 hover:text-blue-900 dark:text-blue-400 dark:hover:text-blue-600" aria-label="{{ __('reset_password') }}">
                                        <x-custom-icon icon="lock-reset"/>
                                    </button>
                                </form>
                                @unless($member->is(auth()->user()))
                                    <x-delete-button action="{{ route('family.members.destroy', $member) }}" />
                                @endunless
                            </div>
                        </td>
                    </tr>
                @endforeach
            </tbody>
        </table>
    </div>
</x-app-layout>
