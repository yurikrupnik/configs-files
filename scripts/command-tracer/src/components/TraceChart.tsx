import React, { useMemo } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, BarChart, Bar, PieChart, Pie, Cell } from 'recharts';
import { TraceEvent } from '../types';
import './TraceChart.css';

interface TraceChartProps {
  traces: TraceEvent[];
}

const TraceChart: React.FC<TraceChartProps> = ({ traces }) => {
  const chartData = useMemo(() => {
    if (traces.length === 0) return { timeline: [], commands: [], status: [] };

    // Timeline data - traces over time
    const timeline = traces.reduce((acc: any[], trace) => {
      const time = new Date(trace.timestamp).toLocaleTimeString();
      const existing = acc.find(item => item.time === time);
      
      if (existing) {
        existing.count += 1;
        existing[trace.status] = (existing[trace.status] || 0) + 1;
      } else {
        acc.push({
          time,
          count: 1,
          [trace.status]: 1,
          started: trace.status === 'started' ? 1 : 0,
          completed: trace.status === 'completed' ? 1 : 0,
          failed: trace.status === 'failed' ? 1 : 0
        });
      }
      
      return acc;
    }, []);

    // Command frequency data
    const commandCounts = traces.reduce((acc: Record<string, number>, trace) => {
      const commandType = trace.command.split(' ')[0]; // Get first word as command type
      acc[commandType] = (acc[commandType] || 0) + 1;
      return acc;
    }, {});

    const commands = Object.entries(commandCounts)
      .map(([command, count]) => ({ command, count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 10); // Top 10 commands

    // Status distribution
    const statusCounts = traces.reduce((acc: Record<string, number>, trace) => {
      acc[trace.status] = (acc[trace.status] || 0) + 1;
      return acc;
    }, {});

    const status = Object.entries(statusCounts).map(([status, count]) => ({
      name: status,
      value: count
    }));

    return { timeline, commands, status };
  }, [traces]);

  const statusColors = {
    started: '#ffc107',
    completed: '#28a745',
    failed: '#dc3545'
  };

  const pieColors = ['#28a745', '#ffc107', '#dc3545'];

  if (traces.length === 0) {
    return (
      <div className="trace-chart">
        <div className="no-data">
          📊 No trace data available yet.<br />
          Run some Nu shell commands to see analytics!
        </div>
      </div>
    );
  }

  return (
    <div className="trace-chart">
      <div className="chart-grid">
        
        {/* Timeline Chart */}
        <div className="chart-section">
          <h3>📈 Command Timeline</h3>
          <ResponsiveContainer width="100%" height={250}>
            <LineChart data={chartData.timeline}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="time" />
              <YAxis />
              <Tooltip />
              <Line 
                type="monotone" 
                dataKey="count" 
                stroke="#8884d8" 
                strokeWidth={2}
                dot={{ r: 4 }}
              />
            </LineChart>
          </ResponsiveContainer>
        </div>

        {/* Command Frequency Chart */}
        <div className="chart-section">
          <h3>🏆 Top Commands</h3>
          <ResponsiveContainer width="100%" height={250}>
            <BarChart data={chartData.commands}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="command" />
              <YAxis />
              <Tooltip />
              <Bar dataKey="count" fill="#8884d8" />
            </BarChart>
          </ResponsiveContainer>
        </div>

        {/* Status Distribution */}
        <div className="chart-section">
          <h3>📊 Status Distribution</h3>
          <ResponsiveContainer width="100%" height={250}>
            <PieChart>
              <Pie
                data={chartData.status}
                cx="50%"
                cy="50%"
                labelLine={false}
                label={({ name, percent }) => `${name} ${((percent || 0) * 100).toFixed(0)}%`}
                outerRadius={80}
                fill="#8884d8"
                dataKey="value"
              >
                {chartData.status.map((entry, index) => (
                  <Cell key={`cell-${index}`} fill={pieColors[index % pieColors.length]} />
                ))}
              </Pie>
              <Tooltip />
            </PieChart>
          </ResponsiveContainer>
        </div>

        {/* Status Timeline */}
        <div className="chart-section">
          <h3>🎯 Status Over Time</h3>
          <ResponsiveContainer width="100%" height={250}>
            <LineChart data={chartData.timeline}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="time" />
              <YAxis />
              <Tooltip />
              <Line 
                type="monotone" 
                dataKey="completed" 
                stroke="#28a745" 
                strokeWidth={2}
                name="Completed"
              />
              <Line 
                type="monotone" 
                dataKey="failed" 
                stroke="#dc3545" 
                strokeWidth={2}
                name="Failed"
              />
              <Line 
                type="monotone" 
                dataKey="started" 
                stroke="#ffc107" 
                strokeWidth={2}
                name="Started"
              />
            </LineChart>
          </ResponsiveContainer>
        </div>

      </div>

      {/* Summary Stats */}
      <div className="stats-summary">
        <div className="stat-card">
          <div className="stat-value">{traces.length}</div>
          <div className="stat-label">Total Commands</div>
        </div>
        
        <div className="stat-card success">
          <div className="stat-value">
            {traces.filter(t => t.status === 'completed').length}
          </div>
          <div className="stat-label">Completed</div>
        </div>
        
        <div className="stat-card warning">
          <div className="stat-value">
            {traces.filter(t => t.status === 'started').length}
          </div>
          <div className="stat-label">In Progress</div>
        </div>
        
        <div className="stat-card danger">
          <div className="stat-value">
            {traces.filter(t => t.status === 'failed').length}
          </div>
          <div className="stat-label">Failed</div>
        </div>
        
        <div className="stat-card">
          <div className="stat-value">
            {traces.filter(t => t.duration).length > 0 
              ? Math.round(traces.filter(t => t.duration).reduce((acc, t) => {
                  const ms = t.duration?.includes('ms') 
                    ? parseInt(t.duration) 
                    : parseInt(t.duration || '0') * 1000;
                  return acc + ms;
                }, 0) / traces.filter(t => t.duration).length)
              : 0}ms
          </div>
          <div className="stat-label">Avg Duration</div>
        </div>
      </div>
    </div>
  );
};

export default TraceChart;