import React, { useEffect, useState } from 'react';
import { subscribeToImages } from '../lib/firebase';
import type { CarouselImage } from '../lib/firebase';
import { DeviceFrame } from './DeviceFrame';

export const PublicViewer: React.FC = () => {
  const [images, setImages] = useState<CarouselImage[]>([]);

  useEffect(() => {
    const unsubscribe = subscribeToImages(setImages);
    return () => {
      if (typeof unsubscribe === 'function') unsubscribe();
    };
  }, []);

  return (
    <div className="min-h-screen w-full bg-neutral-950 flex flex-col items-center justify-center p-4 overflow-hidden relative selection:bg-white/20">
      {/* Background Gradient/Vignette */}
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_center,_var(--tw-gradient-stops))] from-neutral-800/20 via-neutral-950/50 to-neutral-950 pointer-events-none" />
      
      {/* Main Content */}
      <div className="w-full max-w-2xl relative z-10 flex flex-col items-center">
        <DeviceFrame images={images} />
      </div>
    </div>
  );
};
