const express = require('express');
const router = express.Router();
const Transaction = require('../models/Transaction');
const Account = require('../models/Account');
const Category = require('../models/Category');
const { Op } = require('sequelize');
const { authenticateToken } = require('../middleware/auth');

router.use(authenticateToken);

// GET /api/transactions
router.get('/', async (req, res) => {
  try {
    const where = { userId: req.user.id };
    const { accountId, categoryId, type, startDate, endDate, recurring } = req.query;

    if (accountId) where.accountId = accountId;
    if (categoryId) where.categoryId = categoryId;
    if (type) where.type = type;
    if (recurring === 'true') where.isRecurring = true;

    if (startDate || endDate) {
      where.date = {};
      if (startDate) where.date[Op.gte] = startDate;
      if (endDate) where.date[Op.lte] = endDate;
    }

    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 50;
    const offset = (page - 1) * limit;

    const { rows, count } = await Transaction.findAndCountAll({
      where,
      include: [
        { model: Account, attributes: ['id', 'name'] },
        { model: Category, attributes: ['id', 'name', 'icon', 'color'] },
      ],
      order: [['date', 'DESC'], ['createdAt', 'DESC']],
      limit,
      offset,
    });

    res.json({
      transactions: rows,
      total: count,
      page,
      pages: Math.ceil(count / limit),
    });
  } catch (err) {
    console.error('Fetch transactions error:', err.message);
    res.status(500).json({ error: 'Failed to fetch transactions' });
  }
});

function updateBalance(account, amount, type, reverse) {
  const val = parseFloat(amount);
  const bal = parseFloat(account.balance);
  if (type === 'income') {
    account.balance = reverse ? bal - val : bal + val;
  } else if (type === 'expense') {
    account.balance = reverse ? bal + val : bal - val;
  }
  // transfers don't affect balance here - handled separately
}

// POST /api/transactions
router.post('/', async (req, res) => {
  try {
    const { amount, type, description, date, accountId, categoryId,
            isRecurring, recurringInterval, recurringEndDate } = req.body;

    if (!amount || !type || !date || !accountId) {
      return res.status(400).json({ error: 'Missing required fields (amount, type, date, accountId)' });
    }

    const acct = await Account.findOne({ where: { id: accountId, userId: req.user.id } });
    if (!acct) return res.status(404).json({ error: 'Account not found' });

    const tx = await Transaction.create({
      amount,
      type,
      description: description || null,
      date,
      accountId,
      categoryId: categoryId || null,
      userId: req.user.id,
      isRecurring: isRecurring || false,
      recurringInterval: recurringInterval || null,
      recurringEndDate: recurringEndDate || null,
    });

    updateBalance(acct, amount, type, false);
    await acct.save();

    res.status(201).json(tx);
  } catch (err) {
    console.error('Create transaction error:', err.message);
    res.status(500).json({ error: 'Failed to create transaction' });
  }
});

// GET /api/transactions/:id
router.get('/:id', async (req, res) => {
  try {
    const tx = await Transaction.findOne({
      where: { id: req.params.id, userId: req.user.id },
      include: [
        { model: Account, attributes: ['id', 'name'] },
        { model: Category, attributes: ['id', 'name'] },
      ],
    });
    if (!tx) return res.status(404).json({ error: 'Transaction not found' });
    res.json(tx);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch transaction' });
  }
});

// PUT /api/transactions/:id
router.put('/:id', async (req, res) => {
  try {
    const tx = await Transaction.findOne({
      where: { id: req.params.id, userId: req.user.id },
    });
    if (!tx) return res.status(404).json({ error: 'Transaction not found' });

    const fields = ['amount', 'type', 'description', 'date', 'categoryId',
                    'isRecurring', 'recurringInterval', 'recurringEndDate'];
    for (const f of fields) {
      if (req.body[f] !== undefined) tx[f] = req.body[f];
    }
    await tx.save();

    res.json(tx);
  } catch (err) {
    res.status(500).json({ error: 'Failed to update transaction' });
  }
});

// DELETE /api/transactions/:id
router.delete('/:id', async (req, res) => {
  try {
    const tx = await Transaction.findOne({
      where: { id: req.params.id, userId: req.user.id },
    });
    if (!tx) return res.status(404).json({ error: 'Transaction not found' });

    const acct = await Account.findByPk(tx.accountId);
    if (acct) {
      updateBalance(acct, tx.amount, tx.type, true);
      await acct.save();
    }

    await tx.destroy();
    res.json({ message: 'Transaction deleted' });
  } catch (err) {
    res.status(500).json({ error: 'Failed to delete transaction' });
  }
});

module.exports = router;
