describe('Dashboard', () => {
  it('renders without crashing', () => {
    render(<Dashboard />);
    expect(screen.getByText('MeowCoin Node Dashboard')).toBeInTheDocument();
  });

  it('displays nodes', () => {
    render(<Dashboard />);
    expect(screen.getAllByText(/MeowNode-/i)).toHaveLength(2);
  });
});
