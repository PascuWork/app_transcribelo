// scripts.js

document.addEventListener('DOMContentLoaded', function() {
    // console.log('DOM completamente cargado y parseado');

    const select = document.querySelector('.custom-select');
    const trigger = select.querySelector('.custom-select__trigger');
    const options = select.querySelectorAll('.custom-option');
    const hiddenInput = document.getElementById('language');

    trigger.addEventListener('click', function() {
        select.classList.toggle('open');
    });

    options.forEach(option => {
        option.addEventListener('click', function() {
            options.forEach(opt => opt.classList.remove('selected'));
            this.classList.add('selected');
            trigger.innerHTML = this.innerHTML + '<div class="arrow"></div>';
            select.classList.remove('open');
            // Actualizar el valor seleccionado
            hiddenInput.value = this.getAttribute('data-value');
            // console.log('Idioma seleccionado:', hiddenInput.value);
        });
    });

    // Cerrar el selector si se hace clic fuera
    document.addEventListener('click', function(e) {
        if (!select.contains(e.target)) {
            select.classList.remove('open');
        }
    });
});
