import React, { useEffect } from 'react';
import { BrowserRouter, Routes, Route, useLocation } from 'react-router-dom';
import { PublicViewer } from './components/PublicViewer';
import { AdminPanel } from './components/AdminPanel';

// Component to handle injecting meta tags on specific routes
const RouteEffect: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const location = useLocation();

  useEffect(() => {
    // If we are on the admin route, make sure it's not indexed
    if (location.pathname.startsWith('/manage-7f3kx9q2')) {
      let meta = document.querySelector('meta[name="robots"]');
      if (!meta) {
        meta = document.createElement('meta');
        meta.setAttribute('name', 'robots');
        document.head.appendChild(meta);
      }
      meta.setAttribute('content', 'noindex, nofollow');
    } else {
      // Remove it or allow index on public (though public is not meant to be indexed either, but spec says "on the admin route")
      const meta = document.querySelector('meta[name="robots"]');
      if (meta) {
        meta.remove();
      }
    }
  }, [location]);

  return <>{children}</>;
};

function App() {
  return (
    <BrowserRouter>
      <RouteEffect>
        <Routes>
          <Route path="/" element={<PublicViewer />} />
          <Route path="/manage-7f3kx9q2" element={<AdminPanel />} />
        </Routes>
      </RouteEffect>
    </BrowserRouter>
  );
}

export default App;
