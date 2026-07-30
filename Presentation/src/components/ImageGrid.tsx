import React from 'react';
import { DndContext, closestCenter, KeyboardSensor, PointerSensor, useSensor, useSensors } from '@dnd-kit/core';
import type { DragEndEvent } from '@dnd-kit/core';
import { arrayMove, SortableContext, sortableKeyboardCoordinates, rectSortingStrategy, useSortable } from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';
import { Trash2, GripVertical } from 'lucide-react';
import type { CarouselImage } from '../lib/firebase';
import clsx from 'clsx';

interface SortableItemProps {
  image: CarouselImage;
  onDelete: (id: string) => void;
}

const SortableItem: React.FC<SortableItemProps> = ({ image, onDelete }) => {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging
  } = useSortable({ id: image.id });

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
  };

  return (
    <div
      ref={setNodeRef}
      style={style}
      className={clsx(
        "group relative bg-white/5 rounded-xl border border-white/10 overflow-hidden flex flex-col transition-all",
        isDragging ? "opacity-50 scale-95 shadow-xl z-50" : "hover:border-white/30"
      )}
    >
      <div className="aspect-[9/19] w-full bg-black relative p-2">
        <img 
          src={image.url} 
          alt="Thumbnail" 
          className="w-full h-full object-contain rounded"
        />
      </div>
      
      <div className="p-3 flex items-center justify-between bg-black/50 border-t border-white/10">
        <button
          {...attributes}
          {...listeners}
          className="text-white/40 hover:text-white cursor-grab active:cursor-grabbing p-1 rounded hover:bg-white/10 transition-colors"
        >
          <GripVertical size={18} />
        </button>
        <button
          onClick={() => {
            if (window.confirm('Are you sure you want to delete this image?')) {
              onDelete(image.id);
            }
          }}
          className="text-red-400 hover:text-red-300 p-1 rounded hover:bg-red-400/10 transition-colors"
        >
          <Trash2 size={18} />
        </button>
      </div>
    </div>
  );
};

interface ImageGridProps {
  images: CarouselImage[];
  onReorder: (items: CarouselImage[]) => void;
  onDelete: (id: string) => void;
}

export const ImageGrid: React.FC<ImageGridProps> = ({ images, onReorder, onDelete }) => {
  const sensors = useSensors(
    useSensor(PointerSensor),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    })
  );

  const handleDragEnd = (event: DragEndEvent) => {
    const { active, over } = event;
    
    if (over && active.id !== over.id) {
      const oldIndex = images.findIndex(img => img.id === active.id);
      const newIndex = images.findIndex(img => img.id === over.id);
      
      const newItems = arrayMove(images, oldIndex, newIndex);
      onReorder(newItems);
    }
  };

  if (images.length === 0) {
    return (
      <div className="py-12 text-center text-white/50 text-sm">
        No images uploaded yet.
      </div>
    );
  }

  return (
    <DndContext 
      sensors={sensors}
      collisionDetection={closestCenter}
      onDragEnd={handleDragEnd}
    >
      <SortableContext 
        items={images.map(img => img.id)}
        strategy={rectSortingStrategy}
      >
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4">
          {images.map(img => (
            <SortableItem 
              key={img.id} 
              image={img} 
              onDelete={onDelete} 
            />
          ))}
        </div>
      </SortableContext>
    </DndContext>
  );
};
