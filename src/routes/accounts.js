const express = require('express');
const router = express.Router();
const Account = require('../models/Account');
const { authenticateToken } = require('../middleware/auth');

router.use(authenticateToken);

// GET /api/accounts
router.get('/', async (req, res) => {
  try {
    const accounts = await Account.findAll({
      where: { userId: req.user.id },
      order: [['name', 'ASC']],
    });
    res.json(accounts);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch accounts' });
  }
});

// POST /api/accounts
router.post('/', async (req, res) => {
  try {
    const { name, type, currency, balance } = req.body;
    if (!name) return res.status(400).json({ error: 'Account name is required' });

    const account = await Account.create({
      name,
      type: type || 'checking',
      currency: currency || 'USD',
      balance: balance || 0,
      userId: req.user.id,
    });
    res.status(201).json(account);
  } catch (err) {
    res.status(500).json({ error: 'Failed to create account' });
  }
});

// GET /api/accounts/:id
router.get('/:id', async (req, res) => {
  try {
    const account = await Account.findOne({
      where: { id: req.params.id, userId: req.user.id },
    });
    if (!account) return res.status(404).json({ error: 'Account not found' });
    res.json(account);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch account' });
  }
});

// PUT /api/accounts/:id
router.put('/:id', async (req, res) => {
  try {
    const account = await Account.findOne({
      where: { id: req.params.id, userId: req.user.id },
    });
    if (!account) return res.status(404).json({ error: 'Account not found' });

    const { name, type, currency } = req.body;
    if (name) account.name = name;
    if (type) account.type = type;
    if (currency) account.currency = currency;
    await account.save();

    res.json(account);
  } catch (err) {
    res.status(500).json({ error: 'Failed to update account' });
  }
});

// DELETE /api/accounts/:id
router.delete('/:id', async (req, res) => {
  try {
    const account = await Account.findOne({
      where: { id: req.params.id, userId: req.user.id },
    });
    if (!account) return res.status(404).json({ error: 'Account not found' });
    await account.destroy();
    res.json({ message: 'Account deleted' });
  } catch (err) {
    res.status(500).json({ error: 'Failed to delete account' });
  }
});

module.exports = router;
