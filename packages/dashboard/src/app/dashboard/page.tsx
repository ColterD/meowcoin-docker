'use client';

import { useState } from 'react';
import {
  Box,
  Grid,
  Paper,
  Typography,
  Button,
  Card,
  CardContent,
  CardHeader,
  IconButton,
  Divider,
  useTheme,
  Tooltip,
} from '@mui/material';
import {
  Refresh as RefreshIcon,
  MoreVert as MoreVertIcon,
  TrendingUp as TrendingUpIcon,
  Storage as StorageIcon,
  Memory as MemoryIcon,
  Speed as SpeedIcon,
} from '@mui/icons-material';
import { LineChart } from '@mui/x-charts/LineChart';
import { BarChart } from '@mui/x-charts/BarChart';
import { PieChart } from '@mui/x-charts/PieChart';
import { useQuery } from '@tanstack/react-query';
import { api } from '@/lib/api';
import { NodeStatus } from '@meowcoin/shared';

export default function DashboardPage() {
  const theme = useTheme();
  const [refreshKey, setRefreshKey] = useState(0);

  // Fetch node status
  const { data: nodeStatus, isLoading: isLoadingNodes } = useQuery({
    queryKey: ['nodes', refreshKey],
    queryFn: async () => {
      const response = await api.get('/nodes');
      return response.data.data;
    },
  });

  // Fetch blockchain info
  const { data: blockchainInfo, isLoading: isLoadingBlockchain } = useQuery({
    queryKey: ['blockchain', refreshKey],
    queryFn: async () => {
      const response = await api.get('/blockchain/info');
      return response.data.data;
    },
  });

  // Fetch network info
  const { data: networkInfo, isLoading: isLoadingNetwork } = useQuery({
    queryKey: ['network', refreshKey],
    queryFn: async () => {
      const response = await api.get('/network/info');
      return response.data.data;
    },
  });

  // Fetch historical data
  const { data: historicalData, isLoading: isLoadingHistorical } = useQuery({
    queryKey: ['historical', refreshKey],
    queryFn: async () => {
      const response = await api.get('/analytics/historical');
      return response.data.data;
    },
  });

  const handleRefresh = () => {
    setRefreshKey((prev) => prev + 1);
  };

  // Mock data for charts
  const blockTimeData = {
    xAxis: [
      {
        data: Array.from({ length: 24 }, (_, i) => i),
        scaleType: 'linear',
      },
    ],
    series: [
      {
        data: Array.from({ length: 24 }, () => Math.floor(Math.random() * 50) + 100),
        label: 'Block Time (seconds)',
        color: theme.palette.primary.main,
      },
    ],
  };

  const transactionData = {
    xAxis: [
      {
        data: Array.from({ length: 7 }, (_, i) => i),
        scaleType: 'linear',
      },
    ],
    series: [
      {
        data: Array.from({ length: 7 }, () => Math.floor(Math.random() * 1000) + 500),
        label: 'Transactions',
        color: theme.palette.secondary.main,
      },
    ],
  };

  const nodeStatusData = [
    { id: 0, value: 65, label: 'Running', color: theme.palette.success.main },
    { id: 1, value: 25, label: 'Syncing', color: theme.palette.warning.main },
    { id: 2, value: 10, label: 'Stopped', color: theme.palette.error.main },
  ];

  return (
    <Box>
      <Box
        sx={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          mb: 3,
        }}
      >
        <Typography variant="h4" component="h1">
          Dashboard
        </Typography>
        <Button
          variant="contained"
          startIcon={<RefreshIcon />}
          onClick={handleRefresh}
        >
          Refresh
        </Button>
      </Box>

      <Grid container spacing={3}>
        {/* Summary Cards */}
        <Grid item xs={12} md={6} lg={3}>
          <Paper
            elevation={2}
            sx={{
              p: 2,
              display: 'flex',
              flexDirection: 'column',
              height: 140,
              borderLeft: `4px solid ${theme.palette.primary.main}`,
            }}
          >
            <Box
              sx={{
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'flex-start',
              }}
            >
              <Typography color="textSecondary" variant="subtitle2" gutterBottom>
                BLOCKCHAIN HEIGHT
              </Typography>
              <TrendingUpIcon color="primary" />
            </Box>
            <Typography component="p" variant="h4" sx={{ mt: 1 }}>
              {isLoadingBlockchain ? '...' : blockchainInfo?.blocks || 0}
            </Typography>
            <Typography color="textSecondary" sx={{ flex: 1 }}>
              Last block: {isLoadingBlockchain ? '...' : '2 minutes ago'}
            </Typography>
          </Paper>
        </Grid>

        <Grid item xs={12} md={6} lg={3}>
          <Paper
            elevation={2}
            sx={{
              p: 2,
              display: 'flex',
              flexDirection: 'column',
              height: 140,
              borderLeft: `4px solid ${theme.palette.secondary.main}`,
            }}
          >
            <Box
              sx={{
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'flex-start',
              }}
            >
              <Typography color="textSecondary" variant="subtitle2" gutterBottom>
                ACTIVE NODES
              </Typography>
              <StorageIcon color="secondary" />
            </Box>
            <Typography component="p" variant="h4" sx={{ mt: 1 }}>
              {isLoadingNodes ? '...' : nodeStatus?.length || 0}
            </Typography>
            <Typography color="textSecondary" sx={{ flex: 1 }}>
              {isLoadingNodes
                ? '...'
                : `${
                    nodeStatus?.filter((node: any) => node.status === NodeStatus.RUNNING)
                      .length || 0
                  } running`}
            </Typography>
          </Paper>
        </Grid>

        <Grid item xs={12} md={6} lg={3}>
          <Paper
            elevation={2}
            sx={{
              p: 2,
              display: 'flex',
              flexDirection: 'column',
              height: 140,
              borderLeft: `4px solid ${theme.palette.success.main}`,
            }}
          >
            <Box
              sx={{
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'flex-start',
              }}
            >
              <Typography color="textSecondary" variant="subtitle2" gutterBottom>
                NETWORK HASHRATE
              </Typography>
              <MemoryIcon sx={{ color: theme.palette.success.main }} />
            </Box>
            <Typography component="p" variant="h4" sx={{ mt: 1 }}>
              {isLoadingNetwork ? '...' : '1.23 PH/s'}
            </Typography>
            <Typography color="textSecondary" sx={{ flex: 1 }}>
              +5.3% from last week
            </Typography>
          </Paper>
        </Grid>

        <Grid item xs={12} md={6} lg={3}>
          <Paper
            elevation={2}
            sx={{
              p: 2,
              display: 'flex',
              flexDirection: 'column',
              height: 140,
              borderLeft: `4px solid ${theme.palette.warning.main}`,
            }}
          >
            <Box
              sx={{
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'flex-start',
              }}
            >
              <Typography color="textSecondary" variant="subtitle2" gutterBottom>
                AVERAGE BLOCK TIME
              </Typography>
              <SpeedIcon sx={{ color: theme.palette.warning.main }} />
            </Box>
            <Typography component="p" variant="h4" sx={{ mt: 1 }}>
              {isLoadingBlockchain ? '...' : '2.5 min'}
            </Typography>
            <Typography color="textSecondary" sx={{ flex: 1 }}>
              Last 24 hours
            </Typography>
          </Paper>
        </Grid>

        {/* Charts */}
        <Grid item xs={12} md={8}>
          <Card>
            <CardHeader
              title="Block Time (Last 24 Hours)"
              action={
                <IconButton aria-label="settings">
                  <MoreVertIcon />
                </IconButton>
              }
            />
            <Divider />
            <CardContent>
              <Box sx={{ height: 300 }}>
                <LineChart
                  xAxis={blockTimeData.xAxis}
                  series={blockTimeData.series}
                  height={300}
                />
              </Box>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} md={4}>
          <Card>
            <CardHeader
              title="Node Status"
              action={
                <IconButton aria-label="settings">
                  <MoreVertIcon />
                </IconButton>
              }
            />
            <Divider />
            <CardContent>
              <Box sx={{ height: 300 }}>
                <PieChart
                  series={[
                    {
                      data: nodeStatusData,
                      innerRadius: 60,
                      outerRadius: 80,
                      paddingAngle: 2,
                      cornerRadius: 5,
                      startAngle: -90,
                      endAngle: 270,
                    },
                  ]}
                  height={300}
                />
              </Box>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12}>
          <Card>
            <CardHeader
              title="Transactions per Day (Last Week)"
              action={
                <IconButton aria-label="settings">
                  <MoreVertIcon />
                </IconButton>
              }
            />
            <Divider />
            <CardContent>
              <Box sx={{ height: 300 }}>
                <BarChart
                  xAxis={transactionData.xAxis}
                  series={transactionData.series}
                  height={300}
                />
              </Box>
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Box>
  );
}