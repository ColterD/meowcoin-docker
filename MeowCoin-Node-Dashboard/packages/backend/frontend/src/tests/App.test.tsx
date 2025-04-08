describe('App', () => {
  it('renders without crashing', () => {
    render(<App />);
    expect(screen.getByText(/Welcome to MeowCoin Node Dashboard/i)).toBeInTheDocument();
  });

  it('navigates to dashboard', () => {
    render(<App />);
    fireEvent.click(screen.getByText(/Go to Dashboard/i));
    expect(screen.getByText('MeowCoin Node Dashboard')).toBeInTheDocument();
  });
});
