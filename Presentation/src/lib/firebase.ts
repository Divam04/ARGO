import { initializeApp } from 'firebase/app';
import { getAuth, signInWithEmailAndPassword, onAuthStateChanged, signOut, User } from 'firebase/auth';
import { getFirestore, collection, onSnapshot, doc, setDoc, deleteDoc, updateDoc, Timestamp, writeBatch } from 'firebase/firestore';
import { getStorage, ref, uploadBytesResumable, getDownloadURL, deleteObject } from 'firebase/storage';

const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
  appId: import.meta.env.VITE_FIREBASE_APP_ID
};

export const isMockMode = !firebaseConfig.apiKey;

const app = isMockMode ? null : initializeApp(firebaseConfig);
export const auth = isMockMode ? null : getAuth(app!);
export const db = isMockMode ? null : getFirestore(app!);
export const storage = isMockMode ? null : getStorage(app!);

// Types
export interface CarouselImage {
  id: string;
  url: string;
  storagePath: string;
  order: number;
  uploadedAt: Timestamp | null;
}

// Mock Data
let mockImages: CarouselImage[] = [
  {
    id: 'mock-1',
    url: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?q=80&w=2564&auto=format&fit=crop',
    storagePath: 'carousel/mock-1.jpg',
    order: 0,
    uploadedAt: null
  },
  {
    id: 'mock-2',
    url: 'https://images.unsplash.com/photo-1550684848-fac1c5b4e853?q=80&w=2670&auto=format&fit=crop',
    storagePath: 'carousel/mock-2.jpg',
    order: 1,
    uploadedAt: null
  },
  {
    id: 'mock-3',
    url: 'https://images.unsplash.com/photo-1506744626753-1fa28f673b0c?q=80&w=3000&auto=format&fit=crop',
    storagePath: 'carousel/mock-3.jpg',
    order: 2,
    uploadedAt: null
  }
];

let mockSubscribers: ((images: CarouselImage[]) => void)[] = [];
const notifyMockSubscribers = () => {
  const sorted = [...mockImages].sort((a, b) => a.order - b.order);
  mockSubscribers.forEach(sub => sub(sorted));
};

export const subscribeToImages = (callback: (images: CarouselImage[]) => void) => {
  if (isMockMode) {
    mockSubscribers.push(callback);
    notifyMockSubscribers();
    return () => {
      mockSubscribers = mockSubscribers.filter(sub => sub !== callback);
    };
  }

  const q = collection(db!, 'images');
  return onSnapshot(q, (snapshot) => {
    const images: CarouselImage[] = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    } as CarouselImage));
    images.sort((a, b) => a.order - b.order);
    callback(images);
  });
};

export const uploadMockImage = (file: File) => {
  return new Promise<void>((resolve) => {
    setTimeout(() => {
      const newImage: CarouselImage = {
        id: `mock-${Date.now()}`,
        url: URL.createObjectURL(file), // create local url for testing
        storagePath: `carousel/mock-${Date.now()}`,
        order: mockImages.length,
        uploadedAt: null
      };
      mockImages.push(newImage);
      notifyMockSubscribers();
      resolve();
    }, 1000);
  });
};

export const deleteMockImage = (id: string) => {
  return new Promise<void>((resolve) => {
    setTimeout(() => {
      mockImages = mockImages.filter(img => img.id !== id);
      notifyMockSubscribers();
      resolve();
    }, 300);
  });
};

export const reorderMockImages = (items: CarouselImage[]) => {
  return new Promise<void>((resolve) => {
    setTimeout(() => {
      mockImages = items.map((item, index) => ({ ...item, order: index }));
      notifyMockSubscribers();
      resolve();
    }, 200);
  });
};
