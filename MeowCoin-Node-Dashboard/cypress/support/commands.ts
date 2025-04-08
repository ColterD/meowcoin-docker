Cypress.Commands.add('login', () => {
  cy.request({
    method: 'POST',
    url: 'http://localhost:3000/api/login',
    body: { username: 'admin', password: 'password' },
  }).then((response) => {
    window.localStorage.setItem('token', response.body.token);
  });
});
