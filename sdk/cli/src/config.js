
import dotenv from 'dotenv'
import inquirer from 'inquirer'
import emailValidator from 'email-validator'
import fs from 'fs'

dotenv.config()

function to_keys(joined_by_col) {
  const [pub, priv] = joined_by_col.split(':')
  if (pub == null || priv == null) {
    return null;
  }
  return {
    pub, priv
  }
}

const config = {
  org: process.env.ORG_NAME,
  user: process.env.AUTH_USER,
  password: process.env.AUTH_PASSWORD,
  url: process.env.API_URL || 'https://api.proca.foundation',
  keys: (process.env.KEYS || '').split(',').map(to_keys).filter(x => x !== null)
}

function storeConfig(config, fn) {
  let data = ''

  const vars = {
    'ORG_NAME': config.org,
    'AUTH_USER': config.user,
    'AUTH_PASSWORD': config.password,
    'API_URL': config.url,
    'KEYS': config.keys.map(({pub, priv}) =>  `${pub}:${priv}`).join(',')
  }

  for (let [k, v] of Object.entries(vars)) {
    if (v) {
      data += `${k}=${v}\n`
    }
  }

  fs.writeFile(fn, data, (err) => {
    if (err) return console.log(err);
  })
}

async function setup() {
  let k1 
  if (config.keys.length > 0) {
    k1 = config.keys[0]
  } else {
    k1 = { pub: null, priv: null }
  }

  const info = await inquirer.prompt([
    {type:'input', name: 'org', default: config.org, message: 'What is the short name of your org?'},
    {type:'input', name: 'user', default: config.user, message: 'What is your username (email)?',
     validate: emailValidator.validate},
    {type:'password', name: 'password', default: config.password, messsage: 'Your password?'},
    {type:'input', name: 'url', default: config.url, message: 'Proca backend url'},
    {type:'input', name: 'pub', default: k1.pub, message: 'Public key'},
    {type:'password', name: 'priv', default: k1.priv, message: 'Private key'}

  ]).catch((error) => {
    console.log(`Wrong! ${error}`)
    return {}
  })

  info.keys = [{ pub: info.pub, priv: info.priv }]
  storeConfig(info, '.env')
}


module.exports = Object.assign(config, {
  setup: setup
})