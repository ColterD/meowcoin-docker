describe('Dashboard', () => {
  it('loads successfully', () => {
    cy.visit('/dashboard');
    cy.get('h1').should('contain', 'MeowCoin Node Dashboard');
  });

  it('displays node status', () => {
    cy.visit('/dashboard');
    cy.get('.node-status').should('have.length.at.least', 1);
  });
});
