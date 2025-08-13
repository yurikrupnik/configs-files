import React from 'react';
import { TraceEvent } from '../types';
import './TraceList.css';

interface TraceListProps {
  traces: TraceEvent[];
  onClear: () => void;
}

const TraceList: React.FC<TraceListProps> = ({ traces, onClear }) => {
  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'started': return '⏳';
      case 'completed': return '✅';
      case 'failed': return '❌';
      default: return '❓';
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'started': return 'orange';
      case 'completed': return 'green';
      case 'failed': return 'red';
      default: return 'gray';
    }
  };

  const formatDuration = (duration?: string) => {
    if (!duration) return '';
    
    // Parse duration string like "2sec 500ms"
    const match = duration.match(/(\d+)sec|(\d+)ms/g);
    if (!match) return duration;
    
    let totalMs = 0;
    match.forEach(part => {
      if (part.includes('sec')) {
        totalMs += parseInt(part) * 1000;
      } else if (part.includes('ms')) {
        totalMs += parseInt(part);
      }
    });
    
    return totalMs > 1000 ? `${(totalMs / 1000).toFixed(1)}s` : `${totalMs}ms`;
  };

  return (
    <div className="trace-list">
      <div className="trace-list-header">
        <h2>Command Traces ({traces.length})</h2>
        <button onClick={onClear} className="clear-btn">
          🧹 Clear
        </button>
      </div>
      
      <div className="trace-items">
        {traces.length === 0 ? (
          <div className="no-traces">
            🔍 No traces yet. Run some Nu shell commands to see them here!
          </div>
        ) : (
          traces.slice().reverse().map((trace) => (
            <div key={trace.id} className={`trace-item ${trace.status}`}>
              <div className="trace-header">
                <span className="trace-status" style={{ color: getStatusColor(trace.status) }}>
                  {getStatusIcon(trace.status)}
                </span>
                <span className="trace-command">{trace.command}</span>
                <span className="trace-time">
                  {new Date(trace.timestamp).toLocaleTimeString()}
                </span>
              </div>
              
              <div className="trace-details">
                <small>
                  PID: {trace.pid} | 
                  CWD: {trace.cwd.replace(process.env.HOME || '', '~')} |
                  {trace.duration && ` Duration: ${formatDuration(trace.duration)} |`}
                  Status: {trace.status}
                </small>
                
                {trace.data && trace.data.error && (
                  <div className="trace-error">
                    ⚠️ Error: {trace.data.error}
                  </div>
                )}
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
};

export default TraceList;