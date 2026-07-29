document.addEventListener('DOMContentLoaded', () => {
  // DOM Elements
  const apiKeyInput = document.getElementById('apiKey');
  const toggleKeyBtn = document.getElementById('toggleKeyBtn');
  const modelSelect = document.getElementById('modelSelect');
  const projectIdInput = document.getElementById('projectId');
  const regionSelect = document.getElementById('regionSelect');
  const tabBtns = document.querySelectorAll('.tab-btn');
  const tabContents = document.querySelectorAll('.tab-content');
  const presetCards = document.querySelectorAll('.preset-card');
  const dropZone = document.getElementById('dropZone');
  const fileInput = document.getElementById('fileInput');
  const imagePreview = document.getElementById('imagePreview');
  const previewPlaceholder = document.getElementById('previewPlaceholder');
  const imageMeta = document.getElementById('imageMeta');
  const scanBtn = document.getElementById('scanBtn');
  
  // Webcam elements
  const webcamVideo = document.getElementById('webcamVideo');
  const webcamCanvas = document.getElementById('webcamCanvas');
  const startCamBtn = document.getElementById('startCamBtn');
  const captureCamBtn = document.getElementById('captureCamBtn');
  let camStream = null;

  // Results elements
  const statusBadge = document.getElementById('statusBadge');
  const loadingState = document.getElementById('loadingState');
  const emptyState = document.getElementById('emptyState');
  const resultsDisplay = document.getElementById('resultsDisplay');
  const timingBadge = document.getElementById('timingBadge');
  const toggleBtns = document.querySelectorAll('.toggle-btn');
  const viewSections = document.querySelectorAll('.view-section');
  const copyJsonBtn = document.getElementById('copyJsonBtn');
  const simulateSubmitBtn = document.getElementById('simulateSubmitBtn');
  const jsonCodeOutput = document.getElementById('jsonCodeOutput');
  const toastEl = document.getElementById('toast');

  let currentImageBase64 = null;
  let lastExtractedData = null;

  // 1. Load saved values from localStorage
  const savedKey = localStorage.getItem('gemini_api_key');
  if (savedKey) apiKeyInput.value = savedKey;
  const savedProject = localStorage.getItem('gemini_project_id');
  if (savedProject) projectIdInput.value = savedProject;

  apiKeyInput.addEventListener('input', () => {
    localStorage.setItem('gemini_api_key', apiKeyInput.value.trim());
  });
  projectIdInput.addEventListener('input', () => {
    localStorage.setItem('gemini_project_id', projectIdInput.value.trim());
  });

  toggleKeyBtn.addEventListener('click', () => {
    if (apiKeyInput.type === 'password') {
      apiKeyInput.type = 'text';
      toggleKeyBtn.textContent = '🔒';
    } else {
      apiKeyInput.type = 'password';
      toggleKeyBtn.textContent = '👁️';
    }
  });

  // 2. Tab Navigation
  tabBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      tabBtns.forEach(b => b.classList.remove('active'));
      tabContents.forEach(c => c.classList.remove('active'));
      
      btn.classList.add('active');
      const tabId = `tab-${btn.dataset.tab}`;
      document.getElementById(tabId).classList.add('active');

      // Stop webcam if leaving webcam tab
      if (btn.dataset.tab !== 'webcam' && camStream) {
        stopWebcam();
      }
    });
  });

  // 3. Preset Canvas Generator
  presetCards.forEach(card => {
    card.addEventListener('click', () => {
      presetCards.forEach(c => c.classList.remove('selected'));
      card.classList.add('selected');
      
      const presetType = card.dataset.preset;
      generatePresetLabel(presetType);
    });
  });

  function generatePresetLabel(type) {
    const canvas = document.createElement('canvas');
    canvas.width = 600;
    canvas.height = 380;
    const ctx = canvas.getContext('2d');

    // Background
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    ctx.strokeStyle = '#000000';
    ctx.lineWidth = 3;
    ctx.strokeRect(10, 10, canvas.width - 20, canvas.height - 20);

    if (type === 'amazon') {
      // Amazon Header
      ctx.fillStyle = '#232f3e';
      ctx.fillRect(10, 10, canvas.width - 20, 70);
      ctx.fillStyle = '#ffffff';
      ctx.font = 'bold 28px Arial';
      ctx.fillText('amazon prime', 30, 55);
      
      ctx.fillStyle = '#ff9900';
      ctx.font = 'bold 20px Arial';
      ctx.fillText('PRIORITY DELIVERY', 360, 55);

      // Body text
      ctx.fillStyle = '#000000';
      ctx.font = 'bold 22px Arial';
      ctx.fillText('DELIVER TO:', 30, 120);
      ctx.font = '24px Arial';
      ctx.fillText('Dr. Aarav Sharma', 30, 150);
      ctx.font = '18px Arial';
      ctx.fillText('Room 302, Academic Block 2', 30, 180);
      ctx.fillText('Plaksha University Campus, Mohali', 30, 205);
      ctx.font = 'bold 18px Arial';
      ctx.fillText('PHONE: +91 98765-43210', 30, 235);

      // Barcode simulation
      drawBarcode(ctx, 30, 270, 540, 60);
      ctx.font = '16px monospace';
      ctx.fillText('AWB / TRACKING: AZ-114-99283-009', 160, 350);

      setImagePreview(canvas.toDataURL('image/png'), 'Amazon Preset (600x380)');
    } else if (type === 'bluedart') {
      // BlueDart Header
      ctx.fillStyle = '#003366';
      ctx.fillRect(10, 10, canvas.width - 20, 65);
      ctx.fillStyle = '#ffcc00';
      ctx.font = 'bold 30px Arial';
      ctx.fillText('BLUE DART', 30, 52);
      ctx.fillStyle = '#ffffff';
      ctx.font = '18px Arial';
      ctx.fillText('AIR WAYBILL', 420, 50);

      // Details
      ctx.fillStyle = '#000000';
      ctx.font = 'bold 20px Arial';
      ctx.fillText('CONSIGNEE:', 30, 115);
      ctx.font = '24px Arial';
      ctx.fillText('Priya Patel (Batch UG23)', 30, 145);
      ctx.font = '18px Arial';
      ctx.fillText('Gate 1 Security Desk, Plaksha Campus', 30, 175);
      ctx.fillText('Alpha Zone, Sector 101, Mohali, Punjab', 30, 200);
      ctx.font = 'bold 18px Arial';
      ctx.fillText('CONTACT: 080-4912-8833', 30, 230);
      
      ctx.fillText('CARRIER: BlueDart Express Ltd', 320, 230);

      drawBarcode(ctx, 30, 260, 540, 65);
      ctx.font = 'bold 16px monospace';
      ctx.fillText('TRACKING # BD-9823719-IN', 180, 345);

      setImagePreview(canvas.toDataURL('image/png'), 'BlueDart Preset (600x380)');
    } else if (type === 'dhl') {
      // DHL Header
      ctx.fillStyle = '#d40511';
      ctx.fillRect(10, 10, canvas.width - 20, 70);
      ctx.fillStyle = '#ffcc00';
      ctx.font = 'bold 34px Arial';
      ctx.fillText('DHL', 40, 55);
      ctx.font = 'bold 22px Arial';
      ctx.fillText('EXPRESS WORLDWIDE', 140, 52);

      // Details
      ctx.fillStyle = '#000000';
      ctx.font = 'bold 20px Arial';
      ctx.fillText('RECEIVER:', 30, 120);
      ctx.font = '24px Arial';
      ctx.fillText('Prof. Vikram Malhotra', 30, 150);
      ctx.font = '18px Arial';
      ctx.fillText('Faculty Cabin 405, Admin Wing', 30, 180);
      ctx.fillText('Plaksha University, Punjab 140306', 30, 205);
      ctx.font = 'bold 18px Arial';
      ctx.fillText('TEL: +91 91234-56789', 30, 235);
      ctx.fillText('SENDER: TechSupplies Inc, Berlin', 300, 235);

      drawBarcode(ctx, 30, 265, 540, 60);
      ctx.font = 'bold 16px monospace';
      ctx.fillText('WAYBILL NO: 442-9910-2276', 175, 345);

      setImagePreview(canvas.toDataURL('image/png'), 'DHL Preset (600x380)');
    }
  }

  function drawBarcode(ctx, x, y, width, height) {
    ctx.fillStyle = '#000000';
    let currX = x;
    while (currX < x + width) {
      const barWidth = Math.random() > 0.5 ? 4 : 2;
      const gapWidth = Math.random() > 0.5 ? 3 : 2;
      ctx.fillRect(currX, y, barWidth, height);
      currX += barWidth + gapWidth;
    }
  }

  // 4. Drag & Drop / File Input
  dropZone.addEventListener('click', () => fileInput.click());
  
  dropZone.addEventListener('dragover', (e) => {
    e.preventDefault();
    dropZone.classList.add('dragover');
  });

  dropZone.addEventListener('dragleave', () => {
    dropZone.classList.remove('dragover');
  });

  dropZone.addEventListener('drop', (e) => {
    e.preventDefault();
    dropZone.classList.remove('dragover');
    if (e.dataTransfer.files.length > 0) {
      handleFile(e.dataTransfer.files[0]);
    }
  });

  fileInput.addEventListener('change', (e) => {
    if (e.target.files.length > 0) {
      handleFile(e.target.files[0]);
    }
  });

  function handleFile(file) {
    if (!file.type.startsWith('image/')) {
      showToast('Please select a valid image file (PNG, JPG, etc.)', 'error');
      return;
    }
    const reader = new FileReader();
    reader.onload = (e) => {
      setImagePreview(e.target.result, `${file.name} (${Math.round(file.size/1024)} KB)`);
    };
    reader.readAsDataURL(file);
  }

  // 5. Webcam
  startCamBtn.addEventListener('click', async () => {
    try {
      camStream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' } });
      webcamVideo.srcObject = camStream;
      startCamBtn.textContent = '🔴 Stop Camera';
      startCamBtn.onclick = stopWebcam;
      captureCamBtn.disabled = false;
    } catch (err) {
      showToast('Could not access camera. Please allow camera permissions.', 'error');
    }
  });

  function stopWebcam() {
    if (camStream) {
      camStream.getTracks().forEach(track => track.stop());
      camStream = null;
      webcamVideo.srcObject = null;
      startCamBtn.textContent = 'Turn On Camera';
      startCamBtn.onclick = () => startCamBtn.click();
      captureCamBtn.disabled = true;
    }
  }

  captureCamBtn.addEventListener('click', () => {
    webcamCanvas.width = webcamVideo.videoWidth || 640;
    webcamCanvas.height = webcamVideo.videoHeight || 480;
    const ctx = webcamCanvas.getContext('2d');
    ctx.drawImage(webcamVideo, 0, 0, webcamCanvas.width, webcamCanvas.height);
    const dataUrl = webcamCanvas.toDataURL('image/png');
    setImagePreview(dataUrl, `Webcam Capture (${webcamCanvas.width}x${webcamCanvas.height})`);
    showToast('Snapshot captured!', 'success');
  });

  function setImagePreview(base64, metaText) {
    currentImageBase64 = base64;
    imagePreview.src = base64;
    imagePreview.classList.remove('hidden');
    previewPlaceholder.classList.add('hidden');
    imageMeta.textContent = metaText;
    scanBtn.disabled = false;
    
    // Automatically select first preset card if triggered from there
    statusBadge.textContent = 'Image Ready';
    statusBadge.className = 'status-indicator';
  }

  // 6. View Toggles (Cards vs JSON)
  toggleBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      toggleBtns.forEach(b => b.classList.remove('active'));
      viewSections.forEach(s => s.classList.remove('active'));
      
      btn.classList.add('active');
      const viewId = `view${btn.dataset.view.charAt(0).toUpperCase() + btn.dataset.view.slice(1)}`;
      document.getElementById(viewId).classList.add('active');
    });
  });

  // 7. Scan Label Button Click (AI Inference)
  scanBtn.addEventListener('click', async () => {
    if (!currentImageBase64) return;

    // Set UI to loading
    scanBtn.disabled = true;
    statusBadge.textContent = 'Analyzing Visuals...';
    statusBadge.className = 'status-indicator loading';
    loadingState.classList.remove('hidden');
    emptyState.classList.add('hidden');
    resultsDisplay.classList.add('hidden');

    try {
      const response = await fetch('/api/scan-label', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          image: currentImageBase64,
          apiKey: apiKeyInput.value.trim(),
          model: modelSelect.value,
          projectId: projectIdInput.value.trim(),
          region: regionSelect.value
        })
      });

      const result = await response.json();

      if (!response.ok || result.error) {
        throw new Error(result.error || 'Failed to analyze label');
      }

      lastExtractedData = result.data;
      renderResults(result.data, result.durationMs);
      statusBadge.textContent = 'Extraction Complete';
      statusBadge.className = 'status-indicator success';
      showToast('✨ Shipping label successfully scanned!', 'success');

    } catch (err) {
      statusBadge.textContent = 'Extraction Failed';
      statusBadge.className = 'status-indicator error';
      emptyState.classList.remove('hidden');
      showToast(`Error: ${err.message}`, 'error');
    } finally {
      loadingState.classList.add('hidden');
      scanBtn.disabled = false;
    }
  });

  function renderResults(data, durationMs) {
    resultsDisplay.classList.remove('hidden');
    timingBadge.textContent = `⚡ Extracted in ${durationMs}ms via ${modelSelect.value}`;

    // Populate field cards
    document.getElementById('valRecipient').textContent = data.recipientName || 'Not found';
    document.getElementById('valTracking').textContent = data.trackingNumber || 'Not found';
    document.getElementById('valCourier').textContent = data.courierCompany || 'Not found';
    document.getElementById('valPhone').textContent = data.phoneNumber || 'Not found';
    document.getElementById('valAddress').textContent = data.address || 'Not found';
    document.getElementById('valSender').textContent = data.senderName || 'Not found';

    // Populate JSON code
    jsonCodeOutput.textContent = JSON.stringify(data, null, 2);
  }

  // 8. Copy JSON & Simulate Submit
  copyJsonBtn.addEventListener('click', () => {
    if (!lastExtractedData) return;
    navigator.clipboard.writeText(JSON.stringify(lastExtractedData, null, 2));
    showToast('📋 JSON copied to clipboard!', 'success');
  });

  simulateSubmitBtn.addEventListener('click', () => {
    if (!lastExtractedData) return;
    const recipient = lastExtractedData.recipientName || 'Student/Staff';
    const tracking = lastExtractedData.trackingNumber || 'AWB-1002';
    const pid = 'PLU2607' + Math.floor(1000 + Math.random() * 9000);
    
    showToast(`🚀 [AutoParcel Intake] Parcel #${pid} (${tracking}) logged for ${recipient}! Automated SMS reminder sent via Twilio.`, 'success');
  });

  function showToast(message, type = 'normal') {
    toastEl.textContent = message;
    toastEl.style.borderColor = type === 'error' ? '#ef4444' : type === 'success' ? '#10b981' : '#6366f1';
    toastEl.classList.remove('hidden');
    
    clearTimeout(toastEl.timer);
    toastEl.timer = setTimeout(() => {
      toastEl.classList.add('hidden');
    }, 4500);
  }

  // Select first preset by default on startup
  setTimeout(() => {
    document.querySelector('.preset-card[data-preset="amazon"]').click();
  }, 200);
});
