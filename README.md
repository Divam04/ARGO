# ARGO — Automated Parcel Management System

ARGO is an automated parcel intake and notification system built for **Plaksha University's Gate-1**. It replaces manual parcel logging with a pipeline that scans incoming package labels, identifies recipients, and automatically notifies them by email — cutting down the time security staff spend on manual entry and the time students spend wondering if their parcel has arrived.

## Overview

When a parcel arrives at Gate-1, ARGO:
1. Captures an image of the shipping label
2. Extracts recipient details (name, roll number, etc.) using OCR
3. Cross-references the extracted details against university records
4. Optionally verifies the recipient via face recognition at pickup
5. Sends an automated email notification to the recipient
6. Logs the parcel in a searchable record via the web dashboard

## Features

- **OCR-based label scanning** — extracts text from parcel labels using PaddleOCR / EasyOCR
- **Face recognition verification** — confirms recipient identity at pickup using InsightFace
- **Automated email notifications** — sends arrival alerts via the Microsoft Graph API
- **Web dashboard** — FastAPI backend with a React frontend for gate staff to manage and search parcel records
- **Custom-trained detection model** — a YOLOv8-nano model (trained on a Roboflow-labeled dataset) for locating and reading parcel labels in live camera feeds

## Tech Stack

| Layer | Technology |
|---|---|
| Backend | FastAPI (Python) |
| Frontend | React |
| OCR | PaddleOCR / EasyOCR |
| Object Detection | YOLOv8-nano (custom-trained) |
| Face Recognition | InsightFace |
| Notifications | Microsoft Graph API |
| Dataset Labeling | Roboflow |

## Project Structure

```
argo/
├── backend/              # FastAPI application
│   ├── app/
│   │   ├── ocr/          # PaddleOCR / EasyOCR pipeline
│   │   ├── face_recognition/  # InsightFace integration
│   │   ├── notifications/     # Microsoft Graph API email sending
│   │   ├── models/       # DB models / schemas
│   │   └── api/           # API routes
│   └── requirements.txt
├── frontend/             # React dashboard
│   ├── src/
│   └── package.json
├── ml/                   # YOLOv8-nano training + inference
│   ├── dataset/          # Roboflow-exported dataset
│   ├── train.py
│   └── weights/
└── README.md
```

> Update this tree to match your actual repo layout before publishing.

## Getting Started

### Prerequisites

- Python 3.10+
- Node.js 18+
- A Microsoft Azure AD app registration (for Graph API email sending)
- (Optional) A CUDA-capable GPU for faster OCR / YOLOv8 inference

### Backend Setup

```bash
cd backend
python -m venv venv
source venv/bin/activate   # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

Create a `.env` file with:

```
MS_GRAPH_CLIENT_ID=your_client_id
MS_GRAPH_CLIENT_SECRET=your_client_secret
MS_GRAPH_TENANT_ID=your_tenant_id
DATABASE_URL=your_database_url
```

Run the server:

```bash
uvicorn app.main:app --reload
```

### Frontend Setup

```bash
cd frontend
npm install
npm run dev
```

### ML Pipeline (Label Detection + OCR)

The parcel label detector is a custom YOLOv8-nano model trained on a dataset labeled in Roboflow.

```bash
cd ml
pip install -r requirements.txt
python train.py --data dataset/data.yaml --model yolov8n.pt --epochs 100
```

Run live inference on a camera feed:

```bash
python detect_and_read.py --source 0   # webcam
```

## How It Works

1. **Detection** — YOLOv8-nano locates the shipping label region within the camera frame.
2. **OCR** — The cropped label region is passed to PaddleOCR/EasyOCR to extract recipient name, ID, or address text.
3. **Matching** — Extracted text is matched against student/staff records in the database.
4. **Notification** — On a successful match, an email is sent to the recipient via the Microsoft Graph API.
5. **Pickup Verification** — At collection time, InsightFace confirms the recipient's identity against their registered photo before the parcel is released.

## Roadmap

- [ ] Improve OCR accuracy on low-quality/handwritten labels
- [ ] Add SMS notifications as a fallback channel
- [ ] Build an analytics view for parcel volume trends
- [ ] Deploy face recognition to an edge device at the gate for lower latency

## Contributing

This project is developed as part of coursework/extracurricular work at Plaksha University. Contributions, issue reports, and suggestions are welcome via pull requests.

## Author

**Divam** — BTech Computer Science and AI, Plaksha University
AI/ML Subsystem Trainee, Team Kalki (University Rover Challenge)

## License

Specify a license (e.g., MIT) once you're ready to open-source this repository.
