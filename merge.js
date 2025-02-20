const fs = require('fs')

const finalDir = './gas_snapshots' 
const dataDir = './snapshots'

const fileNames = [
    "preSorted.json",
    "runtimeSort.json",
    "runtimeSortTransient.json"
]

fileNames.forEach(file => {
    const finalPath = `${finalDir}/${file}`
    const dataPath = `${dataDir}/${file}`
    const final = JSON.parse(fs.readFileSync(finalPath, 'utf-8'))
    const data = JSON.parse(fs.readFileSync(dataPath, 'utf-8'))
    fs.writeFileSync(finalPath, JSON.stringify({ ...final, ...data }, null, 2))
})
