const fs = require('fs')
const path = require('path')

const BUILD_DIR = path.resolve(__dirname, '../build')

fs.rmSync(BUILD_DIR, { recursive: true, force: true })

console.log(`removed ${BUILD_DIR} if it existed`)
