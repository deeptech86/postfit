/**
 * MomCare API - Socket.io Service
 *
 * Real-time features including:
 * - Community chat
 * - Live notifications
 * - Workout tracking sync
 * - Partner dashboard updates
 */

const { Server } = require('socket.io');
const jwt = require('jsonwebtoken');
const config = require('../config');
const logger = require('../utils/logger');
const { User } = require('../models');

let io;

/**
 * Initialize Socket.io server
 * @param {http.Server} server - HTTP server instance
 * @returns {Server} Socket.io server
 */
function initializeSocketIO(server) {
  io = new Server(server, {
    cors: {
      origin: config.security.corsOrigins,
      methods: ['GET', 'POST'],
      credentials: true,
    },
    pingTimeout: 60000,
    pingInterval: 25000,
    transports: ['websocket', 'polling'],
  });

  // Authentication middleware
  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth.token || socket.handshake.headers.authorization?.replace('Bearer ', '');

      if (!token) {
        return next(new Error('Authentication required'));
      }

      const decoded = jwt.verify(token, config.jwt.secret);
      const user = await User.findById(decoded.sub);

      if (!user || !user.is_active) {
        return next(new Error('User not found or inactive'));
      }

      socket.user = user;
      next();
    } catch (error) {
      logger.error('Socket authentication failed', { error: error.message });
      next(new Error('Authentication failed'));
    }
  });

  // Connection handler
  io.on('connection', (socket) => {
    const userId = socket.user.id;

    logger.info('Socket connected', { userId, socketId: socket.id });

    // Join user's personal room
    socket.join(`user:${userId}`);

    // Handle joining community rooms
    socket.on('join:community', (roomId) => {
      socket.join(`community:${roomId}`);
      logger.debug('Joined community room', { userId, roomId });
    });

    socket.on('leave:community', (roomId) => {
      socket.leave(`community:${roomId}`);
      logger.debug('Left community room', { userId, roomId });
    });

    // Handle community chat messages
    socket.on('chat:message', async (data) => {
      try {
        const { roomId, message } = data;

        // Validate and save message (implement in chat service)
        const savedMessage = {
          id: Date.now().toString(),
          userId: socket.user.id,
          userName: socket.user.name,
          message,
          timestamp: new Date().toISOString(),
        };

        // Broadcast to room
        io.to(`community:${roomId}`).emit('chat:message', savedMessage);

        logger.debug('Chat message sent', { userId, roomId });
      } catch (error) {
        socket.emit('error', { message: 'Failed to send message' });
      }
    });

    // Handle typing indicators
    socket.on('chat:typing', (data) => {
      const { roomId, isTyping } = data;
      socket.to(`community:${roomId}`).emit('chat:typing', {
        userId: socket.user.id,
        userName: socket.user.name,
        isTyping,
      });
    });

    // Handle workout sync
    socket.on('workout:start', (data) => {
      // Notify partner if connected
      const partnerId = data.partnerId;
      if (partnerId) {
        io.to(`user:${partnerId}`).emit('workout:started', {
          userId: socket.user.id,
          userName: socket.user.name,
          workoutId: data.workoutId,
        });
      }
    });

    socket.on('workout:complete', (data) => {
      // Notify partner
      const partnerId = data.partnerId;
      if (partnerId) {
        io.to(`user:${partnerId}`).emit('workout:completed', {
          userId: socket.user.id,
          userName: socket.user.name,
          workoutId: data.workoutId,
          duration: data.duration,
          caloriesBurned: data.caloriesBurned,
        });
      }
    });

    // Handle hydration reminders acknowledgment
    socket.on('hydration:logged', (data) => {
      // Update partner dashboard if enabled
      const partnerId = data.partnerId;
      if (partnerId) {
        io.to(`user:${partnerId}`).emit('progress:updated', {
          userId: socket.user.id,
          type: 'hydration',
          amount: data.amount,
        });
      }
    });

    // Handle encouragement messages
    socket.on('encouragement:send', (data) => {
      const { targetUserId, message } = data;

      io.to(`user:${targetUserId}`).emit('encouragement:received', {
        fromUserId: socket.user.id,
        fromUserName: socket.user.name,
        message,
        timestamp: new Date().toISOString(),
      });

      logger.info('Encouragement sent', { from: userId, to: targetUserId });
    });

    // Handle disconnect
    socket.on('disconnect', (reason) => {
      logger.info('Socket disconnected', { userId, socketId: socket.id, reason });
    });

    // Handle errors
    socket.on('error', (error) => {
      logger.error('Socket error', { userId, error: error.message });
    });
  });

  logger.info('Socket.io initialized');

  return io;
}

/**
 * Get Socket.io instance
 * @returns {Server}
 */
function getIO() {
  if (!io) {
    throw new Error('Socket.io not initialized');
  }
  return io;
}

/**
 * Send notification to user
 * @param {string} userId - User ID
 * @param {Object} notification - Notification data
 */
function sendNotification(userId, notification) {
  if (!io) return;

  io.to(`user:${userId}`).emit('notification', {
    ...notification,
    timestamp: new Date().toISOString(),
  });
}

/**
 * Send achievement notification
 * @param {string} userId - User ID
 * @param {Object} achievement - Achievement data
 */
function sendAchievementNotification(userId, achievement) {
  if (!io) return;

  io.to(`user:${userId}`).emit('achievement:earned', {
    ...achievement,
    timestamp: new Date().toISOString(),
  });
}

/**
 * Broadcast to community room
 * @param {string} roomId - Room ID
 * @param {string} event - Event name
 * @param {Object} data - Event data
 */
function broadcastToCommunity(roomId, event, data) {
  if (!io) return;

  io.to(`community:${roomId}`).emit(event, data);
}

/**
 * Send progress update to partner
 * @param {string} partnerId - Partner user ID
 * @param {Object} progress - Progress data
 */
function sendProgressToPartner(partnerId, progress) {
  if (!io) return;

  io.to(`user:${partnerId}`).emit('progress:updated', {
    ...progress,
    timestamp: new Date().toISOString(),
  });
}

module.exports = {
  initializeSocketIO,
  getIO,
  sendNotification,
  sendAchievementNotification,
  broadcastToCommunity,
  sendProgressToPartner,
};
