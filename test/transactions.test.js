const request = require('supertest');
const app = require('../src/app');
const { sequelize } = require('../src/models');

let token;
let accountId;

beforeAll(async () => {
  await sequelize.sync({ force: true });

  // create a user
  const regRes = await request(app)
    .post('/api/auth/register')
    .send({ username: 'txuser', email: 'tx@test.com', password: 'testpass123' });
  token = regRes.body.token;

  // create an account
  const acctRes = await request(app)
    .post('/api/accounts')
    .set('Authorization', `Bearer ${token}`)
    .send({ name: 'Checking', type: 'checking', balance: 1000 });
  accountId = acctRes.body.id;
});

afterAll(async () => {
  await sequelize.close();
});

describe('Transaction endpoints', () => {
  let txId;

  it('should create a transaction', async () => {
    const res = await request(app)
      .post('/api/transactions')
      .set('Authorization', `Bearer ${token}`)
      .send({
        amount: 50.00,
        type: 'expense',
        description: 'Groceries',
        date: '2025-11-15',
        accountId,
      });

    expect(res.status).toBe(201);
    expect(res.body.amount).toBe(50);
    expect(res.body.type).toBe('expense');
    txId = res.body.id;
  });

  it('should update account balance on expense', async () => {
    const res = await request(app)
      .get(`/api/accounts/${accountId}`)
      .set('Authorization', `Bearer ${token}`);

    expect(parseFloat(res.body.balance)).toBe(950);
  });

  it('should list transactions', async () => {
    const res = await request(app)
      .get('/api/transactions')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.transactions.length).toBeGreaterThan(0);
    expect(res.body).toHaveProperty('total');
    expect(res.body).toHaveProperty('page');
  });

  it('should filter by date range', async () => {
    const res = await request(app)
      .get('/api/transactions?startDate=2025-11-01&endDate=2025-11-30')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.transactions.length).toBe(1);
  });

  it('should get single transaction', async () => {
    const res = await request(app)
      .get(`/api/transactions/${txId}`)
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.description).toBe('Groceries');
  });

  it('should update a transaction', async () => {
    const res = await request(app)
      .put(`/api/transactions/${txId}`)
      .set('Authorization', `Bearer ${token}`)
      .send({ description: 'Groceries (Costco)' });

    expect(res.status).toBe(200);
    expect(res.body.description).toBe('Groceries (Costco)');
  });

  it('should create recurring transaction', async () => {
    const res = await request(app)
      .post('/api/transactions')
      .set('Authorization', `Bearer ${token}`)
      .send({
        amount: 1200,
        type: 'expense',
        description: 'Rent',
        date: '2025-12-01',
        accountId,
        isRecurring: true,
        recurringInterval: 'monthly',
      });

    expect(res.status).toBe(201);
    expect(res.body.isRecurring).toBe(true);
    expect(res.body.recurringInterval).toBe('monthly');
  });

  it('should filter recurring transactions', async () => {
    const res = await request(app)
      .get('/api/transactions?recurring=true')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.transactions.length).toBe(1);
    expect(res.body.transactions[0].isRecurring).toBe(true);
  });

  it('should delete a transaction and reverse balance', async () => {
    const balanceBefore = await request(app)
      .get(`/api/accounts/${accountId}`)
      .set('Authorization', `Bearer ${token}`);

    const res = await request(app)
      .delete(`/api/transactions/${txId}`)
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);

    const balanceAfter = await request(app)
      .get(`/api/accounts/${accountId}`)
      .set('Authorization', `Bearer ${token}`);

    // should have added back the 50 expense
    expect(parseFloat(balanceAfter.body.balance)).toBe(parseFloat(balanceBefore.body.balance) + 50);
  });

  it('should require auth', async () => {
    const res = await request(app).get('/api/transactions');
    expect(res.status).toBe(401);
  });

  it('should reject missing required fields', async () => {
    const res = await request(app)
      .post('/api/transactions')
      .set('Authorization', `Bearer ${token}`)
      .send({ description: 'incomplete' });

    expect(res.status).toBe(400);
  });
});
