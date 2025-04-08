import React from 'react';

const NotFound: React.FC = () => {
  return (
    <div className="container mx-auto p-4 text-center">
      <h1 className="text-3xl font-bold">404 - Not Found</h1>
      <p className="mt-4">The page you are looking for does not exist.</p>
      <a href="/" className="mt-4 inline-block bg-blue-500 text-white p-2 rounded">
        Go Home
      </a>
    </div>
  );
};

export default NotFound;
