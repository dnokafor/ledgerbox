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
    const { accountId, categoryId, type, startDate, endDate } = req.query;

    if (accountId) where.accountId = accountId;
    if (categoryId) where.categoryId = categoryId;
    if (type) where.type = type;

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

// POST /api/transactions
router.post('/', async (req, res) => {
  try {
    const { amount, type, description, date, accountId, categoryId } = req.body;

    if (!amount || !type || !date || !accountId) {
      return res.status(400).json({ error: 'Missing required fields (amount, type, date, accountId)' });
    }

    // verify the account belongs to user
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
    });

    // update account balance
    if (type === 'income') {
      acct.balance = parseFloat(acct.balance) + parseFloat(amount);
    } else if (type === 'expense') {
      acct.balance = parseFloat(acct.balance) - parseFloat(amount);
    }
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

    const { amount, type, description, date, categoryId } = req.body;
    if (amount !== undefined) tx.amount = amount;
    if (type) tx.type = type;
    if (description !== undefined) tx.description = description;
    if (date) tx.date = date;
    if (categoryId !== undefined) tx.categoryId = categoryId;
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

    // reverse the balance change
    const acct = await Account.findByPk(tx.accountId);
    if (acct) {
      if (tx.type === 'income') {
        acct.balance = parseFloat(acct.balance) - parseFloat(tx.amount);
      } else if (tx.type === 'expense') {
        acct.balance = parseFloat(acct.balance) + parseFloat(tx.amount);
      }
      await acct.save();
    }

    await tx.destroy();
    res.json({ message: 'Transaction deleted' });
  } catch (err) {
    res.status(500).json({ error: 'Failed to delete transaction' });
  }
});

module.exports = router;
