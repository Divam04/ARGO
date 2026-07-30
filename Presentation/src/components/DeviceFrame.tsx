import React, { useState } from 'react';
import { Swiper, SwiperSlide } from 'swiper/react';
import { Pagination, Keyboard, A11y } from 'swiper/modules';
import { Wifi, BatteryMedium, ChevronDown, Minus, Square, X } from 'lucide-react';
import clsx from 'clsx';
import type { CarouselImage } from '../lib/firebase';
import 'swiper/css';
import 'swiper/css/pagination';

interface DeviceFrameProps {
  images: CarouselImage[];
  showDebugBadge?: boolean;
}

export const DeviceFrame: React.FC<DeviceFrameProps> = ({ images, showDebugBadge = false }) => {
  const [currentTime, setCurrentTime] = useState(() => {
    const now = new Date();
    return now.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: false }) + 
           ', ' + now.toLocaleDateString('en-US', { day: '2-digit', month: 'short' });
  });

  // Simple clock effect
  React.useEffect(() => {
    const interval = setInterval(() => {
      const now = new Date();
      setCurrentTime(now.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: false }) + 
             ', ' + now.toLocaleDateString('en-US', { day: '2-digit', month: 'short' }));
    }, 60000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="relative flex flex-col items-center justify-center w-full max-w-md mx-auto">
      {/* Device Frame */}
      <div className="relative w-full aspect-[9/19] rounded-[48px] bg-white/5 backdrop-blur-2xl border border-white/15 shadow-[0_0_80px_rgba(255,255,255,0.05)] overflow-hidden flex flex-col">
        
        {/* Debug Badge */}
        {showDebugBadge && (
          <div className="absolute top-6 -right-8 bg-red-600 text-white text-[10px] font-bold uppercase tracking-wider py-1 px-10 rotate-45 z-50 shadow-lg">
            DEBUG
          </div>
        )}

        {/* Status Bar */}
        <div className="flex items-center justify-between px-6 pt-5 pb-2 text-white/90 text-xs font-medium z-10">
          <span>{currentTime}</span>
          <div className="flex items-center gap-2">
            <Wifi size={14} />
            <BatteryMedium size={16} />
          </div>
        </div>

        {/* Browser Chrome */}
        <div className="flex items-center justify-between px-5 py-3 border-b border-white/10 z-10 bg-black/20">
          <div className="flex items-center gap-3 text-white/50">
            <div className="w-6 h-6 rounded-full bg-white/10 flex items-center justify-center">
              <ChevronDown size={14} className="rotate-90" />
            </div>
            <div className="flex items-center gap-1">
              <span className="text-xs font-medium text-white/40">my-app.localhost</span>
              <ChevronDown size={12} />
            </div>
          </div>
          <div className="flex items-center gap-3 text-white/40">
            <Minus size={14} />
            <Square size={12} />
            <X size={14} />
          </div>
        </div>

        {/* Content Area - Swiper */}
        <div className="flex-1 relative bg-black/40">
          {images.length === 0 ? (
            <div className="absolute inset-0 flex items-center justify-center text-white/50 text-sm p-8 text-center font-medium">
              No screens uploaded yet &mdash; check back soon
            </div>
          ) : (
            <Swiper
              modules={[Pagination, Keyboard, A11y]}
              spaceBetween={0}
              slidesPerView={1}
              keyboard={{ enabled: true }}
              pagination={{ 
                clickable: true,
                el: '.custom-pagination',
                bulletClass: 'custom-bullet',
                bulletActiveClass: 'custom-bullet-active',
              }}
              className="w-full h-full"
            >
              {images.map((img) => (
                <SwiperSlide key={img.id} className="w-full h-full p-6">
                  <div className="w-full h-full rounded-2xl bg-white overflow-hidden shadow-2xl relative">
                    <img 
                      src={img.url} 
                      alt="Showcase screen" 
                      className="absolute inset-0 w-full h-full object-contain"
                    />
                  </div>
                </SwiperSlide>
              ))}
            </Swiper>
          )}
        </div>
      </div>

      {/* External Controls */}
      {images.length > 0 && (
        <div className="mt-8 flex flex-col items-center gap-4">
          <div className="custom-pagination flex items-center justify-center gap-2 h-8 px-4 rounded-full bg-white/5 backdrop-blur-md border border-white/10"></div>
          
          <div className="bg-white/5 backdrop-blur-md border border-white/10 px-4 py-1.5 rounded-full">
            <span className="text-[10px] uppercase tracking-[0.2em] text-white/50 font-medium">
              Swipe to browse
            </span>
          </div>
        </div>
      )}

      {/* Global styles for Swiper custom pagination */}
      <style>{`
        .custom-bullet {
          width: 6px;
          height: 6px;
          border-radius: 50%;
          background: rgba(255, 255, 255, 0.2);
          cursor: pointer;
          transition: all 0.3s ease;
        }
        .custom-bullet-active {
          width: 24px;
          border-radius: 12px;
          background: rgba(255, 255, 255, 0.9);
        }
      `}</style>
    </div>
  );
};
