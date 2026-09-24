/* Local Blob downloads avoid browser requests to Shinylive's virtual URLs. */
(function () {
  'use strict';
  let objectUrl = null;
  function clearFile() {
    if (objectUrl) URL.revokeObjectURL(objectUrl);
    objectUrl = null;
    const panel = document.getElementById('balloon-file-ready');
    if (panel) panel.replaceChildren();
  }
  $(document).on('shiny:connected', function () {
    Shiny.addCustomMessageHandler('balloon-file-clear', function (message) { clearFile(); });
    Shiny.addCustomMessageHandler('balloon-file', function (file) {
      clearFile();
      const panel = document.getElementById('balloon-file-ready');
      if (!panel) return;
      try {
        const binary = atob(file.data);
        const bytes = Uint8Array.from(binary, c => c.charCodeAt(0));
        objectUrl = URL.createObjectURL(new Blob([bytes], {type: file.mime}));
        const link = document.createElement('a');
        link.href = objectUrl;
        link.download = file.filename;
        link.className = 'btn btn-primary';
        link.textContent = 'Save ' + file.filename;
        panel.append(document.createTextNode('Your file is ready. Click to save: '), link);
        panel.style.padding = '16px 0';
        // A real second click preserves user activation in restrictive browsers.
      } catch (error) {
        panel.textContent = 'Could not prepare the download: ' + error.message;
      }
    });
  });
  window.addEventListener('beforeunload', clearFile);
})();
