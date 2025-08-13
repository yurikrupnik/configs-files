import React, { useState, useEffect } from 'react';
import {
  Container,
  Grid,
  Paper,
  Typography,
  Box,
  Card,
  CardContent,
  CardHeader,
  Chip,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
} from '@mui/material';
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  LineChart,
  Line,
} from 'recharts';
import { Cluster, Application, CostMetrics } from '../types';

const mockClusters: Cluster[] = [
  {
    id: '1',
    name: 'local-dev',
    environment: 'local',
    type: 'local',
    status: 'running',
    uptime: 12.5,
    nodeCount: 1,
    cost: { current: 0, budget: 100, currency: 'USD' },
  },
  {
    id: '2',
    name: 'staging',
    environment: 'staging',
    type: 'aks',
    status: 'running',
    uptime: 168,
    nodeCount: 3,
    cost: { current: 245, budget: 1000, currency: 'USD' },
    region: 'eastus',
  },
  {
    id: '3',
    name: 'production',
    environment: 'production',
    type: 'gke',
    status: 'running',
    uptime: 720,
    nodeCount: 5,
    cost: { current: 1250, budget: 5000, currency: 'USD' },
    region: 'us-central1',
  },
];

const mockApps: Application[] = [
  { name: 'crossplane', namespace: 'crossplane-system', status: 'running', version: '1.14.0', enabled: true },
  { name: 'argocd', namespace: 'argocd', status: 'running', version: '5.46.0', enabled: true },
  { name: 'prometheus', namespace: 'monitoring', status: 'running', version: '51.0.0', enabled: true },
  { name: 'loki', namespace: 'monitoring', status: 'running', version: '2.9.10', enabled: true },
];

const costData = [
  { name: 'Local', cost: 0 },
  { name: 'Staging', cost: 245 },
  { name: 'Production', cost: 1250 },
];

const uptimeData = [
  { name: 'Day 1', uptime: 99.9 },
  { name: 'Day 2', uptime: 99.8 },
  { name: 'Day 3', uptime: 100 },
  { name: 'Day 4', uptime: 99.7 },
  { name: 'Day 5', uptime: 99.9 },
  { name: 'Day 6', uptime: 100 },
  { name: 'Day 7', uptime: 99.8 },
];

export const ClusterDashboard: React.FC = () => {
  const [clusters, setClusters] = useState<Cluster[]>(mockClusters);
  const [applications, setApplications] = useState<Application[]>(mockApps);

  const totalCost = clusters.reduce((sum, cluster) => sum + cluster.cost.current, 0);
  const totalBudget = clusters.reduce((sum, cluster) => sum + cluster.cost.budget, 0);

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'running': return 'success';
      case 'stopped': return 'warning';
      case 'error': return 'error';
      default: return 'default';
    }
  };

  return (
    <Container maxWidth="xl" sx={{ mt: 4, mb: 4 }}>
      <Typography variant="h4" gutterBottom>
        Cluster Management Dashboard
      </Typography>

      {/* Overview Cards */}
      <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 3, mb: 4 }}>
        <Box sx={{ flex: { xs: '1 1 100%', sm: '1 1 calc(50% - 12px)', md: '1 1 calc(25% - 18px)' } }}>
          <Card>
            <CardContent>
              <Typography color="text.secondary" gutterBottom>
                Total Clusters
              </Typography>
              <Typography variant="h4">
                {clusters.length}
              </Typography>
            </CardContent>
          </Card>
        </Box>
        <Box sx={{ flex: { xs: '1 1 100%', sm: '1 1 calc(50% - 12px)', md: '1 1 calc(25% - 18px)' } }}>
          <Card>
            <CardContent>
              <Typography color="text.secondary" gutterBottom>
                Running Clusters
              </Typography>
              <Typography variant="h4">
                {clusters.filter(c => c.status === 'running').length}
              </Typography>
            </CardContent>
          </Card>
        </Box>
        <Box sx={{ flex: { xs: '1 1 100%', sm: '1 1 calc(50% - 12px)', md: '1 1 calc(25% - 18px)' } }}>
          <Card>
            <CardContent>
              <Typography color="text.secondary" gutterBottom>
                Total Cost
              </Typography>
              <Typography variant="h4">
                ${totalCost}
              </Typography>
            </CardContent>
          </Card>
        </Box>
        <Box sx={{ flex: { xs: '1 1 100%', sm: '1 1 calc(50% - 12px)', md: '1 1 calc(25% - 18px)' } }}>
          <Card>
            <CardContent>
              <Typography color="text.secondary" gutterBottom>
                Budget Usage
              </Typography>
              <Typography variant="h4">
                {((totalCost / totalBudget) * 100).toFixed(1)}%
              </Typography>
            </CardContent>
          </Card>
        </Box>
      </Box>

      <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 3 }}>
        {/* Clusters Table */}
        <Box sx={{ flex: { xs: '1 1 100%', md: '1 1 calc(66.666% - 12px)' } }}>
          <Paper sx={{ p: 2 }}>
            <Typography variant="h6" gutterBottom>
              Clusters
            </Typography>
            <TableContainer>
              <Table>
                <TableHead>
                  <TableRow>
                    <TableCell>Name</TableCell>
                    <TableCell>Environment</TableCell>
                    <TableCell>Type</TableCell>
                    <TableCell>Status</TableCell>
                    <TableCell>Nodes</TableCell>
                    <TableCell>Uptime</TableCell>
                    <TableCell>Cost</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {clusters.map((cluster) => (
                    <TableRow key={cluster.id}>
                      <TableCell>{cluster.name}</TableCell>
                      <TableCell>
                        <Chip label={cluster.environment} size="small" />
                      </TableCell>
                      <TableCell>{cluster.type.toUpperCase()}</TableCell>
                      <TableCell>
                        <Chip 
                          label={cluster.status} 
                          color={getStatusColor(cluster.status) as any}
                          size="small"
                        />
                      </TableCell>
                      <TableCell>{cluster.nodeCount}</TableCell>
                      <TableCell>{cluster.uptime}h</TableCell>
                      <TableCell>${cluster.cost.current}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          </Paper>
        </Box>

        {/* Applications */}
        <Box sx={{ flex: { xs: '1 1 100%', md: '1 1 calc(33.333% - 12px)' } }}>
          <Paper sx={{ p: 2 }}>
            <Typography variant="h6" gutterBottom>
              Applications
            </Typography>
            {applications.map((app) => (
              <Box key={app.name} sx={{ mb: 2 }}>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <Typography variant="body1">{app.name}</Typography>
                  <Chip 
                    label={app.status} 
                    color={getStatusColor(app.status) as any}
                    size="small"
                  />
                </Box>
                <Typography variant="body2" color="text.secondary">
                  {app.namespace} • v{app.version}
                </Typography>
              </Box>
            ))}
          </Paper>
        </Box>

        {/* Cost Chart */}
        <Box sx={{ flex: { xs: '1 1 100%', md: '1 1 calc(50% - 12px)' } }}>
          <Paper sx={{ p: 2 }}>
            <Typography variant="h6" gutterBottom>
              Cost by Environment
            </Typography>
            <ResponsiveContainer width="100%" height={300}>
              <BarChart data={costData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="name" />
                <YAxis />
                <Tooltip formatter={(value) => [`$${value}`, 'Cost']} />
                <Bar dataKey="cost" fill="#8884d8" />
              </BarChart>
            </ResponsiveContainer>
          </Paper>
        </Box>

        {/* Uptime Chart */}
        <Box sx={{ flex: { xs: '1 1 100%', md: '1 1 calc(50% - 12px)' } }}>
          <Paper sx={{ p: 2 }}>
            <Typography variant="h6" gutterBottom>
              Uptime Trends
            </Typography>
            <ResponsiveContainer width="100%" height={300}>
              <LineChart data={uptimeData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="name" />
                <YAxis domain={[99, 100]} />
                <Tooltip formatter={(value) => [`${value}%`, 'Uptime']} />
                <Line type="monotone" dataKey="uptime" stroke="#82ca9d" strokeWidth={2} />
              </LineChart>
            </ResponsiveContainer>
          </Paper>
        </Box>
      </Box>
    </Container>
  );
};
