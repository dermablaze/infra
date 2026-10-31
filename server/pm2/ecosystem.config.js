// PM2 process config for DermaBlaze API
// Deploy: pm2 start ecosystem.config.js
// Save:   pm2 save

module.exports = {
  apps: [
    {
      name: 'dermablaze-api',
      script: 'dist/server.js',
      cwd: '/opt/dermablaze-api',
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: '512M',
      env: {
        NODE_ENV: 'production',
        PORT: 3000,
      },
      error_file: '/var/log/dermablaze/api-error.log',
      out_file: '/var/log/dermablaze/api-out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss',
    },
  ],
}
