const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "http://localhost:3000",
    methods: ["GET", "POST"]
  }
});

const PORT = process.env.PORT || 3001;
const TRACE_FILE = '/tmp/nu-commands.jsonl';

// Middleware
app.use(cors());
app.use(express.json());

// Store for trace events
let traceEvents = [];
let clients = new Set();

// Socket.io connection handling
io.on('connection', (socket) => {
  console.log('Client connected:', socket.id);
  clients.add(socket);
  
  // Send existing traces to new client
  socket.emit('initial-traces', traceEvents);
  
  socket.on('disconnect', () => {
    console.log('Client disconnected:', socket.id);
    clients.delete(socket);
  });
  
  // Handle client requesting system info
  socket.on('get-system-info', () => {
    exec('uname -a && ps aux | grep -E "(kind|kubectl|helm)" | grep -v grep', (error, stdout, stderr) => {
      socket.emit('system-info', {
        timestamp: new Date().toISOString(),
        system: stdout || 'System info unavailable',
        error: error ? error.message : null
      });
    });
  });
});

// API Routes
app.post('/api/trace', (req, res) => {
  const traceEvent = {
    ...req.body,
    received_at: new Date().toISOString()
  };
  
  traceEvents.push(traceEvent);
  
  // Keep only last 1000 events to prevent memory issues
  if (traceEvents.length > 1000) {
    traceEvents = traceEvents.slice(-1000);
  }
  
  // Broadcast to all connected clients
  io.emit('new-trace', traceEvent);
  
  console.log('Trace received:', traceEvent.command, traceEvent.status);
  res.status(200).json({ success: true });
});

app.get('/api/traces', (req, res) => {
  res.json(traceEvents);
});

app.get('/api/traces/clear', (req, res) => {
  traceEvents = [];
  io.emit('traces-cleared');
  res.json({ success: true, message: 'Traces cleared' });
});

// Health check
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString(),
    connected_clients: clients.size,
    total_traces: traceEvents.length
  });
});

// File watcher for trace file
if (fs.existsSync(TRACE_FILE)) {
  console.log('Watching trace file:', TRACE_FILE);
  
  fs.watchFile(TRACE_FILE, (curr, prev) => {
    if (curr.mtime > prev.mtime) {
      // File was modified, read new content
      try {
        const content = fs.readFileSync(TRACE_FILE, 'utf8');
        const lines = content.split('\n').filter(line => line.trim());
        
        // Process only new lines
        const newLines = lines.slice(traceEvents.length);
        
        newLines.forEach(line => {
          try {
            const traceEvent = JSON.parse(line);
            traceEvent.received_at = new Date().toISOString();
            traceEvents.push(traceEvent);
            
            // Broadcast to clients
            io.emit('new-trace', traceEvent);
          } catch (e) {
            console.error('Error parsing trace line:', e.message);
          }
        });
        
        // Keep only last 1000 events
        if (traceEvents.length > 1000) {
          traceEvents = traceEvents.slice(-1000);
        }
        
      } catch (error) {
        console.error('Error reading trace file:', error.message);
      }
    }
  });
} else {
  console.log('Trace file not found, will create when traces are received');
}

// Periodic cleanup
setInterval(() => {
  // Clean up old traces (older than 1 hour)
  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
  const originalLength = traceEvents.length;
  
  traceEvents = traceEvents.filter(event => {
    const eventTime = new Date(event.timestamp);
    return eventTime > oneHourAgo;
  });
  
  if (traceEvents.length !== originalLength) {
    console.log(`Cleaned up ${originalLength - traceEvents.length} old traces`);
  }
}, 5 * 60 * 1000); // Run every 5 minutes

server.listen(PORT, () => {
  console.log(`🚀 Trace server running on port ${PORT}`);
  console.log(`📊 Dashboard available at http://localhost:3000`);
  console.log(`🔍 API health check: http://localhost:${PORT}/api/health`);
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\n🛑 Shutting down trace server...');
  io.close();
  server.close(() => {
    console.log('✅ Server closed');
    process.exit(0);
  });
});