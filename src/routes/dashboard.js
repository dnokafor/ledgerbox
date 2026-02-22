const express = require('express');
const router = express.Router();
const Account = require('../models/Account');
const Transaction = require('../models/Transaction');
const Category = require('../models/Category');
const { Op } = require('sequelize');
const { authenticateToken } = require('../middleware/auth');

router.use(authenticateToken);

function getMonthRange(dateStr) {
  // accepts optional ?month=2026-01 query param
  let year, month;
  if (dateStr && /^\d{4}-\d{2}$/.test(dateStr)) {
    [year, month] = dateStr.split('-').map(Number);
  } else {
    const now = new Date();
    year = now.getFullYear();
    month = now.getMonth() + 1;
  }
  const start = `${year}-${String(month).padStart(2, '0')}-01`;
  const lastDay = new Date(year, month, 0).getDate();
  const end = `${year}-${String(month).padStart(2, '0')}-${String(lastDay).padStart(2, '0')}`;
  return { start, end };
}

// GET /api/dashboard
router.get('/', async (req, res) => {
  try {
    const userId = req.user.id;

    const accounts = await Account.findAll({
      where: { userId },
      attributes: ['id', 'name', 'type', 'balance', 'currency'],
    });

    const totalBalance = accounts.reduce((sum, a) => sum + parseFloat(a.balance), 0);

    const { start: monthStart, end: monthEnd } = getMonthRange(req.query.month);

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
