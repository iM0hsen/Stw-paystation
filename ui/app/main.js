function renderUI(data) {
    const app = document.getElementById('app');
    
    if (!data || data.length === 0) {
        app.innerHTML = '<div class="container idle-state"></div>';
        return;
    }

    let html = '<div class="container active-state">';
    data.forEach((veh, i) => {
        html += `
            <div class="row" data-index="${i}">
                <div class="name">
                    <div class="bg-img" style="background-image: url('${veh.backgroundImage}')"></div>
                    <span class="title">${veh.name}</span>
                </div>
                <div class="price">$${veh.price}</div>
            </div>
        `;
    });
    html += `
        <div class="footer">
            <i class="fa-solid fa-circle-x close-icon"></i>
              Backspace To Close
        </div>
    </div>`;
    app.innerHTML = html;

    let selectedIndex = 0;
    const rows = Array.from(document.querySelectorAll('.row'));
    const vehicles = data.slice();

    function applySelection() {
        rows.forEach((r, idx) => {
            if (idx === selectedIndex) r.classList.add('selected');
            else r.classList.remove('selected');
        });
    }

    window.__applySelection = (index) => {
        if (typeof index === 'number') {
            selectedIndex = Math.max(0, Math.min(index, rows.length - 1));
            applySelection();
        }
    };
    window.__vehiclesCount = rows.length;

    applySelection();

}

window.addEventListener('message', function(event) {
    if (event.data.type === "setupUI") {
        renderUI(event.data.vehicles);
    } else if (event.data.type === "hideUI") {
        renderUI(null);
    } else if (event.data.type === "highlight") {
        if (typeof window.__applySelection === 'function') {
            window.__applySelection(event.data.index || 0);
        }
    }
});

window.onload = () => {
    fetch(`https://Stw-paystation/duiReady`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).catch(e => {});
    
    renderUI(null);
};
