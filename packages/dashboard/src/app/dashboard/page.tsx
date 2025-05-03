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
  Alert,
  Snackbar,
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
import { useQuery, UseQueryOptions } from '@tanstack/react-query';
import { api } from '@/lib/api';
import { NodeStatus } from '@meowcoin/shared';

export default function DashboardPage() {
  const theme = useTheme();
  const [refreshKey, setRefreshKey] = useState(0);
  const [errorBanner, setErrorBanner] = useState<string | null>(null);
  const [syncProgress, setSyncProgress] = useState<number | null>(null);

  // Fetch node status
  const {
    data: nodeStatus,
    isLoading: isLoadingNodes,
    error: nodeError,
    refetch: refetchNodes,
  } = useQuery({
    queryKey: ['nodes', refreshKey],
    queryFn: async () => {
      const response = await api.get('/nodes');
      return response.data.data;
    },
    onError: (err: any) => {
      if (err?.status === 503) {
        setErrorBanner('Node is unreachable. Please check your node status and try again.');
      } else if (err?.message) {
        setErrorBanner(err.message);
      } else {
        setErrorBanner('Unknown error fetching node status.');
      }
    },
  } as UseQueryOptions<any, Error>);

  // Fetch blockchain info
  const {
    data: blockchainInfo,
    isLoading: isLoadingBlockchain,
    error: blockchainError,
    refetch: refetchBlockchain,
  } = useQuery({
    queryKey: ['blockchain', refreshKey],
    queryFn: async () => {
      const response = await api.get('/blockchain/info');
      return response.data.data;
    },
    onError: (err: any) => {
      if (err?.status === 503) {
        setErrorBanner('Node is unreachable. Please check your node status and try again.');
      } else if (err?.message) {
        setErrorBanner(err.message);
      } else {
        setErrorBanner('Unknown error fetching blockchain info.');
      }
    },
  } as UseQueryOptions<any, Error>);

  // Fetch health info for sync status
  const {
    data: healthInfo,
    isLoading: isLoadingHealth,
    error: healthError,
    refetch: refetchHealth,
  } = useQuery({
    queryKey: ['health', refreshKey],
    queryFn: async () => {
      const response = await api.get('/health');
      return response.data;
    },
    onSuccess: (data: any) => {
      if (data.status === 'degraded') {
        setErrorBanner(
          `Node is syncing. Some data may be incomplete. Sync progress: ${data.node?.syncProgress ?? '?'}%`
        );
        setSyncProgress(data.node?.syncProgress ?? null);
      } else if (data.status === 'unhealthy') {
        setErrorBanner('Node is unreachable. Please check your node status and try again.');
      } else {
        setErrorBanner(null);
        setSyncProgress(null);
      }
    },
    onError: (err: any) => {
      setErrorBanner('Unable to fetch node health.');
    },
  } as UseQueryOptions<any, Error>);

  // Fetch network info
  const { data: networkInfo, isLoading: isLoadingNetwork } = useQuery({
    queryKey: ['network', refreshKey],
    queryFn: async () => {
      const response = await api.get('/network/info');
      return response.data.data;
    },
    onError: (err: any) => {
      if (err?.status === 503) {
        setErrorBanner('Node is unreachable. Please check your node status and try again.');
      } else if (err?.message) {
        setErrorBanner(err.message);
      } else {
        setErrorBanner('Unknown error fetching network info.');
      }
    },
  } as UseQueryOptions<any, Error>);

  // Fetch historical data
  const { data: historicalData, isLoading: isLoadingHistorical } = useQuery({
    queryKey: ['historical', refreshKey],
    queryFn: async () => {
      const response = await api.get('/analytics/historical');
      return response.data.data;
    },
    onError: (err: any) => {
      if (err?.status === 503) {
        setErrorBanner('Node is unreachable. Please check your node status and try again.');
      } else if (err?.message) {
        setErrorBanner(err.message);
      } else {
        setErrorBanner('Unknown error fetching historical data.');
      }
    },
  } as UseQueryOptions<any, Error>);

  const handleRefresh = () => {
    setRefreshKey((prev: number) => prev + 1);
    setErrorBanner(null);
    setSyncProgress(null);
    refetchNodes();
    refetchBlockchain();
    refetchHealth();
  };

  // --- Refactored: Use real data for charts ---
  // Block Time Chart
  const blockTimeSeries = historicalData?.blockTime as { x: string[]; y: number[] } | undefined;
  const blockTimeData = blockTimeSeries
    ? {
        xAxis: [
          {
            data: blockTimeSeries.x,
            scaleType: 'linear',
          } as { data: string[]; scaleType: 'linear' },
        ],
        series: [
          {
            data: blockTimeSeries.y,
            label: 'Block Time (seconds)',
            color: theme.palette.primary.main,
          },
        ],
      }
    : undefined;

  // Transactions Chart
  const transactionSeries = historicalData?.transactions as { x: string[]; y: number[] } | undefined;
  const transactionData = transactionSeries
    ? {
        xAxis: [
          {
            data: transactionSeries.x,
            scaleType: 'linear',
          } as { data: string[]; scaleType: 'linear' },
        ],
        series: [
          {
            data: transactionSeries.y,
            label: 'Transactions',
            color: theme.palette.secondary.main,
          },
        ],
      }
    : undefined;

  // Node Status Pie Chart
  type NodeStatusType = { status: string };
  const nodeStatusData = nodeStatus
    ? [
        {
          id: 0,
          value: (nodeStatus as NodeStatusType[]).filter((n) => n.status === NodeStatus.RUNNING).length,
          label: 'Running',
          color: theme.palette.success.main,
        },
        {
          id: 1,
          value: (nodeStatus as NodeStatusType[]).filter((n) => n.status === NodeStatus.SYNCING).length,
          label: 'Syncing',
          color: theme.palette.warning.main,
        },
        {
          id: 2,
          value: (nodeStatus as NodeStatusType[]).filter((n) => n.status === NodeStatus.STOPPED).length,
          label: 'Stopped',
          color: theme.palette.error.main,
        },
      ]
    : [];

  return (
    <Box>
      {/* Error Banner */}
      {errorBanner && (
        <Alert severity={syncProgress ? 'warning' : 'error'} sx={{ mb: 2 }} action={
          <Button color="inherit" size="small" onClick={handleRefresh}>
            Retry
          </Button>
        }>
          {errorBanner}
        </Alert>
      )}

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
              {/* TODO: Replace with real last block time from API if available */}
              Last block: {isLoadingBlockchain
                ? '...'
                : blockchainInfo?.lastBlockTime
                  ? blockchainInfo.lastBlockTime
                  : 'N/A'}
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
              {/* TODO: Replace with real network hashrate from API if available */}
              {isLoadingNetwork
                ? '...'
                : networkInfo?.hashrate
                  ? networkInfo.hashrate
                  : 'N/A'}
            </Typography>
            <Typography color="textSecondary" sx={{ flex: 1 }}>
              {/* TODO: Replace with real hashrate change from API if available */}
              {networkInfo?.hashrateChange
                ? `${networkInfo.hashrateChange} from last week`
                : 'N/A'}
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
              {/* TODO: Replace with real average block time from API if available */}
              {isLoadingBlockchain
                ? '...'
                : blockchainInfo?.averageBlockTime
                  ? blockchainInfo.averageBlockTime
                  : 'N/A'}
            </Typography>
            <Typography color="textSecondary" sx={{ flex: 1 }}>
              {/* Optionally, add more context if available from API */}
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
                {isLoadingHistorical ? (
                  <Typography>Loading...</Typography>
                ) : blockTimeData ? (
                  <LineChart
                    xAxis={blockTimeData.xAxis}
                    series={blockTimeData.series}
                    height={300}
                  />
                ) : (
                  <Typography>No data available</Typography>
                )}
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
                {isLoadingNodes ? (
                  <Typography>Loading...</Typography>
                ) : nodeStatusData.length > 0 ? (
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
                ) : (
                  <Typography>No data available</Typography>
                )}
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
                {isLoadingHistorical ? (
                  <Typography>Loading...</Typography>
                ) : transactionData ? (
                  <BarChart
                    xAxis={transactionData.xAxis}
                    series={transactionData.series}
                    height={300}
                  />
                ) : (
                  <Typography>No data available</Typography>
                )}
              </Box>
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Box>
  );
}