import React, { useCallback, useState } from 'react';
import { UploadCloud } from 'lucide-react';
import { uploadMockImage, isMockMode, db, storage } from '../lib/firebase';
import { collection, doc, setDoc, Timestamp } from 'firebase/firestore';
import { ref, uploadBytesResumable, getDownloadURL } from 'firebase/storage';
import clsx from 'clsx';

interface UploadZoneProps {
  currentCount: number;
}

export const UploadZone: React.FC<UploadZoneProps> = ({ currentCount }) => {
  const [isDragging, setIsDragging] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [progress, setProgress] = useState(0);

  const handleDrag = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (e.type === 'dragenter' || e.type === 'dragover') {
      setIsDragging(true);
    } else if (e.type === 'dragleave') {
      setIsDragging(false);
    }
  }, []);

  const processFile = async (file: File) => {
    if (!file.type.startsWith('image/')) return;
    
    setUploading(true);
    setProgress(0);

    if (isMockMode) {
      await uploadMockImage(file);
      setUploading(false);
      setProgress(100);
      return;
    }

    try {
      const ext = file.name.split('.').pop();
      const storagePath = `carousel/${Date.now()}-${Math.random().toString(36).substring(2)}.${ext}`;
      const storageRef = ref(storage!, storagePath);
      
      const uploadTask = uploadBytesResumable(storageRef, file);
      
      uploadTask.on('state_changed', 
        (snapshot) => {
          const p = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
          setProgress(p);
        },
        (error) => {
          console.error('Upload failed', error);
          setUploading(false);
        },
        async () => {
          const url = await getDownloadURL(uploadTask.snapshot.ref);
          const docRef = doc(collection(db!, 'images'));
          await setDoc(docRef, {
            url,
            storagePath,
            order: currentCount,
            uploadedAt: Timestamp.now()
          });
          setUploading(false);
          setProgress(100);
        }
      );
    } catch (err) {
      console.error(err);
      setUploading(false);
    }
  };

  const handleDrop = useCallback(async (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragging(false);

    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      await processFile(e.dataTransfer.files[0]);
    }
  }, [currentCount]);

  const handleChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    e.preventDefault();
    if (e.target.files && e.target.files[0]) {
      await processFile(e.target.files[0]);
    }
  };

  return (
    <div
      onDragEnter={handleDrag}
      onDragLeave={handleDrag}
      onDragOver={handleDrag}
      onDrop={handleDrop}
      className={clsx(
        "relative w-full h-32 rounded-xl border-2 border-dashed transition-colors flex flex-col items-center justify-center overflow-hidden",
        isDragging ? "border-white/50 bg-white/10" : "border-white/20 bg-white/5 hover:bg-white/10"
      )}
    >
      <input
        type="file"
        accept="image/jpeg,image/png,image/webp"
        onChange={handleChange}
        className="absolute inset-0 w-full h-full opacity-0 cursor-pointer z-10"
        disabled={uploading}
      />
      
      {uploading ? (
        <div className="flex flex-col items-center gap-2">
          <div className="text-white/70 text-sm font-medium">Uploading... {Math.round(progress)}%</div>
          <div className="w-48 h-1 bg-white/10 rounded-full overflow-hidden">
            <div 
              className="h-full bg-white transition-all duration-300"
              style={{ width: `${progress}%` }}
            />
          </div>
        </div>
      ) : (
        <>
          <UploadCloud className="text-white/40 mb-2" size={24} />
          <div className="text-white/70 text-sm font-medium">
            Drag & drop an image or click to browse
          </div>
          <div className="text-white/40 text-xs mt-1">
            JPEG, PNG, WEBP
          </div>
        </>
      )}
    </div>
  );
};
