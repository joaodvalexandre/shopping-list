document.addEventListener('livewire:navigated', function() {
    function handleFilterChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;
        Livewire.dispatch('applyFilter', { field: field, value: value });
    }

    // Add event listeners to all filter inputs
    document.querySelectorAll('.filter-input').forEach(function(input) {
        input.addEventListener('change', handleFilterChange);
    });
});
