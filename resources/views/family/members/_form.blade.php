@php
    use App\Enums\FamilyRole;
    use App\Enums\ListAbility;

    $member = $member ?? null;
    $currentRole = old('role', $member?->role?->value ?? FamilyRole::Member->value);
@endphp

<div class="flex flex-col gap-4" x-data="{ role: '{{ $currentRole }}' }">
    <x-input.input name="name" label="name" :value="$member?->name" required />
    @error('name') <p class="text-sm text-red-600 dark:text-red-400">{{ $message }}</p> @enderror

    <x-input.input name="email" label="email" type="email" :value="$member?->email" required />
    @error('email') <p class="text-sm text-red-600 dark:text-red-400">{{ $message }}</p> @enderror

    <div class="w-full flex flex-col gap-1">
        <label for="role" class="text-sm font-medium text-gray-700 dark:text-gray-300">{{ __('role') }}</label>
        <select name="role" id="role" x-model="role"
                class="w-full px-4 py-2 text-sm rounded-lg shadow-xs border border-gray-300 bg-white text-gray-900 dark:bg-gray-800 dark:border-gray-600 dark:text-gray-100">
            @foreach(FamilyRole::cases() as $role)
                <option value="{{ $role->value }}">{{ $role->label() }}</option>
            @endforeach
        </select>
        <p x-show="role === 'admin'" class="text-xs text-gray-500 dark:text-gray-400">{{ __('admin_role_help') }}</p>
    </div>

    <!-- Permissions per list type (admins can do everything) -->
    <div x-show="role !== 'admin'" class="flex flex-col gap-2">
        <div class="text-lg">{{ __('permissions') }}</div>
        <p class="text-xs text-gray-500 dark:text-gray-400">{{ __('permissions_help') }}</p>

        @if($listTypes->isEmpty())
            <p class="text-gray-500 dark:text-gray-400">{{ __('no_list_types_yet') }}</p>
        @else
            <div class="overflow-x-auto">
                <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
                    <thead class="bg-gray-200 dark:bg-gray-600">
                        <tr>
                            <th class="px-4 py-2 text-left text-xs font-medium text-gray-700 dark:text-gray-200 uppercase tracking-wider">{{ __('list_type') }}</th>
                            @foreach(ListAbility::cases() as $ability)
                                <th class="px-3 py-2 text-center text-xs font-medium text-gray-700 dark:text-gray-200 uppercase tracking-wider">{{ $ability->label() }}</th>
                            @endforeach
                        </tr>
                    </thead>
                    <tbody class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
                        @foreach($listTypes as $type)
                            <tr>
                                <td class="px-4 py-2 whitespace-nowrap">{{ $type->name }}</td>
                                @foreach(ListAbility::cases() as $ability)
                                    <td class="px-3 py-2 text-center">
                                        <input type="checkbox"
                                               name="permissions[{{ $type->id }}][{{ $ability->value }}]"
                                               value="1"
                                               class="h-4 w-4 rounded"
                                               @checked(old("permissions.{$type->id}.{$ability->value}", $permissions[$type->id][$ability->value] ?? false))>
                                    </td>
                                @endforeach
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
        @endif
    </div>
</div>
