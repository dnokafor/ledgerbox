const express = require('express');
const router = express.Router();
const Account = require('../models/Account');
const Transaction = require('../models/Transaction');
const Category = require('../models/Category');
const { Op } = require('sequelize');
const sequelize = require('../config/database');
const { authenticateToken } = require('../middleware/auth');

router.use(authenticateToken);

// GET /api/dashboard
router.get('/', async (req, res) => {
  try {
    const userId = req.user.id;

    // get all accounts with balances
    const accounts = await Account.findAll({
      where: { userId },
      attributes: ['id', 'name', 'type', 'balance', 'currency'],
    });

    const totalBalance = accounts.reduce((sum, a) => sum + parseFloat(a.balance), 0);

    // current month boundaries
    const now = new Date();
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1)
      .toISOString().split('T')[0];
    const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0)
      .toISOString().split('T')[0];

    // monthly income & expenses
    const monthlyTxns = await Transaction.findAll({
      where: {
        userId,
        date: { [Op.gte]: monthStart, [Op.lte]: monthEnd },
      },
    });

    let monthIncome = 0;
    let monthExpenses = 0;
    for (const tx of monthlyTxns) {
      if (tx.type === 'income') monthIncome += parseFloat(tx.amount);
      else if (tx.type === 'expense') monthExpenses += parseFloat(tx.amount);
    }

    // recent transactions
    const recent = await Transaction.findAll({
      where: { userId },
      include: [
        { model: Account, attributes: ['name'] },
        { model: Category, attributes: ['name', 'icon', 'color'] },
      ],
      order: [['date', 'DESC']],
      limit: 10,
    });

    res.json({
      accounts,
      totalBalance,
      monthly: {
        income: monthIncome,
        expenses: monthExpenses,
        net: monthIncome - monthExpenses,
        period: `${monthStart} to ${monthEnd}`,
      },
      recentTransactions: recent,
    });
  } catch (err) {
    console.error('Dashboard error:', err.message);
    res.status(500).json({ error: 'Failed to load dashboard' });
  }
});

module.exports = router;
