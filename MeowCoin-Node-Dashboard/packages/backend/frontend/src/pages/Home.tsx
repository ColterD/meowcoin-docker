import React from 'react';

const Home: React.FC = () => {
  return (
    <div className="container mx-auto p-4">
      <h1 className="text-3xl font-bold">Welcome to MeowCoin Node Dashboard</h1>
      <p className="mt-4">Manage your MeowCoin nodes with ease.</p>
      <a href="/dashboard" className="mt-4 inline-block bg-blue-500 text-white p-2 rounded">
        Go to Dashboard
      </a>
    </div>
  );
};

export default Home;
