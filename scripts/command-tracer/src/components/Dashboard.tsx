import React, { useState, useEffect } from 'react';
import io, { Socket } from 'socket.io-client';
import { TraceEvent, SystemInfo, ServerHealth } from '../types';
import TraceList from './TraceList';
import TraceChart from './TraceChart';
import './Dashboard.css';

const Dashboard: React.FC = () => {
  const [socket, setSocket] = useState<Socket | null>(null);
  const [traces, setTraces] = useState<TraceEvent[]>([]);
  const [connected, setConnected] = useState(false);
  const [systemInfo, setSystemInfo] = useState<SystemInfo | null>(null);
  const [serverHealth, setServerHealth] = useState<ServerHealth | null>(null);
  const [activeTab, setActiveTab] = useState<'traces' | 'chart'>('traces');

  useEffect(() => {
    // Connect to socket server
    const newSocket = io('http://localhost:3001');
    setSocket(newSocket);

    // Connection events
    newSocket.on('connect', () => {
      console.log('Connected to trace server');
      setConnected(true);
      
      // Request system info
      newSocket.emit('get-system-info');
    });

    newSocket.on('disconnect', () => {
      console.log('Disconnected from trace server');
      setConnected(false);
    });

    // Trace events
    newSocket.on('initial-traces', (initialTraces: TraceEvent[]) => {
      console.log('Received initial traces:', initialTraces.length);
      setTraces(initialTraces);
    });

    newSocket.on('new-trace', (trace: TraceEvent) => {
      console.log('New trace:', trace.command, trace.status);
      setTraces(prev => [...prev, trace]);
    });

    newSocket.on('traces-cleared', () => {
      console.log('Traces cleared');
      setTraces([]);
    });

    // System info
    newSocket.on('system-info', (info: SystemInfo) => {
      setSystemInfo(info);
    });

    // Fetch server health periodically
    const healthInterval = setInterval(async () => {
      try {
        const response = await fetch('http://localhost:3001/api/health');
        const health = await response.json();
        setServerHealth(health);
      } catch (error) {
        console.error('Failed to fetch server health:', error);
        setServerHealth(null);
      }
    }, 5000);

    return () => {
      newSocket.close();
      clearInterval(healthInterval);
    };
  }, []);

  const handleClearTraces = async () => {
    try {
      await fetch('http://localhost:3001/api/traces/clear');
      // The server will emit 'traces-cleared' event
    } catch (error) {
      console.error('Failed to clear traces:', error);
    }
  };

  const getConnectionStatus = () => {
    if (connected) {
      return { text: '🟢 Connected', color: 'green' };
    } else {
      return { text: '🔴 Disconnected', color: 'red' };
    }
  };

  const connectionStatus = getConnectionStatus();

  return (
    <div className="dashboard">
      <header className="dashboard-header">
        <div className="header-title">
          <h1>🔍 Nu Shell Command Tracer</h1>
          <p>Real-time monitoring of your Nu shell commands</p>
        </div>
        
        <div className="header-status">
          <div className="connection-status" style={{ color: connectionStatus.color }}>
            {connectionStatus.text}
          </div>
          
          {serverHealth && (
            <div className="server-health">
              <div>👥 {serverHealth.connected_clients} clients</div>
              <div>📊 {serverHealth.total_traces} traces</div>
            </div>
          )}
        </div>
      </header>

      <nav className="dashboard-nav">
        <button 
          className={`nav-btn ${activeTab === 'traces' ? 'active' : ''}`}
          onClick={() => setActiveTab('traces')}
        >
          📋 Trace List
        </button>
        <button 
          className={`nav-btn ${activeTab === 'chart' ? 'active' : ''}`}
          onClick={() => setActiveTab('chart')}
        >
          📈 Analytics
        </button>
      </nav>

      <main className="dashboard-content">
        {activeTab === 'traces' && (
          <TraceList traces={traces} onClear={handleClearTraces} />
        )}
        
        {activeTab === 'chart' && (
          <TraceChart traces={traces} />
        )}
      </main>

      {systemInfo && (
        <footer className="dashboard-footer">
          <details className="system-info">
            <summary>🖥️ System Information</summary>
            <pre>{systemInfo.system}</pre>
            {systemInfo.error && (
              <div className="error">Error: {systemInfo.error}</div>
            )}
          </details>
        </footer>
      )}
    </div>
  );
};

export default Dashboard;