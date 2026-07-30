import React, { useEffect, useState } from 'react';
import { onAuthStateChanged, signOut } from 'firebase/auth';
import { doc, writeBatch } from 'firebase/firestore';
import { ref, deleteObject } from 'firebase/storage';
import { LogOut, Link as LinkIcon, Check } from 'lucide-react';
import { auth, db, storage, subscribeToImages, isMockMode, deleteMockImage, reorderMockImages, CarouselImage } from '../lib/firebase';
import { LoginForm } from './LoginForm';
import { UploadZone } from './UploadZone';
import { ImageGrid } from './ImageGrid';

export const AdminPanel: React.FC = () => {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [loading, setLoading] = useState(true);
  const [images, setImages] = useState<CarouselImage[]>([]);
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    if (isMockMode) {
      setLoading(false);
      // In mock mode, we start unauthenticated to test login UI
      setIsAuthenticated(false);
      return;
    }

    const unsubscribe = onAuthStateChanged(auth!, (user) => {
      setIsAuthenticated(!!user);
      setLoading(false);
    });
    return () => unsubscribe();
  }, []);

  useEffect(() => {
    if (!isAuthenticated) return;
    
    const unsubscribe = subscribeToImages(setImages);
    return () => {
      if (typeof unsubscribe === 'function') unsubscribe();
    };
  }, [isAuthenticated]);

  const handleLogout = async () => {
    if (isMockMode) {
      setIsAuthenticated(false);
      return;
    }
    await signOut(auth!);
  };

  const copyLink = () => {
    const url = window.location.origin;
    navigator.clipboard.writeText(url);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleReorder = async (newItems: CarouselImage[]) => {
    setImages(newItems); // Optimistic UI update
    
    if (isMockMode) {
      await reorderMockImages(newItems);
      return;
    }

    try {
      const batch = writeBatch(db!);
      newItems.forEach((img, index) => {
        const docRef = doc(db!, 'images', img.id);
        batch.update(docRef, { order: index });
      });
      await batch.commit();
    } catch (err) {
      console.error('Failed to reorder', err);
    }
  };

  const handleDelete = async (id: string) => {
    if (isMockMode) {
      await deleteMockImage(id);
      return;
    }

    const image = images.find(img => img.id === id);
    if (!image) return;

    try {
      // 1. Delete from storage
      const storageRef = ref(storage!, image.storagePath);
      await deleteObject(storageRef);
      // 2. Delete from firestore (batch update to reorder remaining could be done here, but simplistic for now)
      const docRef = doc(db!, 'images', id);
      const { deleteDoc } = await import('firebase/firestore');
      await deleteDoc(docRef);
    } catch (err) {
      console.error('Failed to delete', err);
      alert('Failed to delete image. Please try again.');
    }
  };

  if (loading) {
    return <div className="min-h-screen bg-black" />;
  }

  if (!isAuthenticated) {
    return <LoginForm onSuccess={() => setIsAuthenticated(true)} />;
  }

  return (
    <div className="min-h-screen bg-neutral-950 text-white p-6 md:p-10 selection:bg-white/20">
      <div className="max-w-6xl mx-auto space-y-10">
        
        {/* Header */}
        <header className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 border-b border-white/10 pb-6">
          <div>
            <h1 className="text-2xl font-semibold tracking-tight">Showcase Management</h1>
            <p className="text-white/50 text-sm mt-1">
              Upload, reorder, and manage images for the public display.
            </p>
          </div>
          <div className="flex items-center gap-3">
            <button
              onClick={copyLink}
              className="flex items-center gap-2 px-4 py-2 bg-white/10 hover:bg-white/15 rounded-lg text-sm font-medium transition-colors"
            >
              {copied ? <Check size={16} className="text-green-400" /> : <LinkIcon size={16} />}
              {copied ? 'Copied!' : 'Copy public link'}
            </button>
            <button
              onClick={handleLogout}
              className="flex items-center gap-2 px-4 py-2 border border-white/10 hover:bg-white/5 rounded-lg text-sm font-medium transition-colors"
            >
              <LogOut size={16} />
              Logout
            </button>
          </div>
        </header>

        {/* Upload Zone */}
        <section>
          <h2 className="text-sm font-medium text-white/70 uppercase tracking-wider mb-4">Upload New Screen</h2>
          <UploadZone currentCount={images.length} />
        </section>

        {/* Image Grid */}
        <section>
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-sm font-medium text-white/70 uppercase tracking-wider">Current Screens</h2>
            <span className="text-xs bg-white/10 px-2 py-1 rounded-full text-white/70">
              {images.length} {images.length === 1 ? 'image' : 'images'}
            </span>
          </div>
          <ImageGrid 
            images={images} 
            onReorder={handleReorder} 
            onDelete={handleDelete} 
          />
        </section>

      </div>
    </div>
  );
};
