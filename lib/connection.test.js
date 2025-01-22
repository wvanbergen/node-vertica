import { expect, describe, test } from 'vitest'
import fs from 'fs'
import net from 'net'

import * as Vertica from './vertica'

describe.runIf(fs.existsSync('./test/connection.json'))('Vertica.connect', () => {
    const connectionInfo = JSON.parse(fs.readFileSync('./test/connection.json'))

    test('should connect to the database', () => new Promise(done => {
        Vertica.connect(connectionInfo, (err, connection) => {
            expect(err).toBeNull()
            if (err) {
                done(err)
                return
            }
            expect(connection.busy).toBe(false)
            expect(connection.connected).toBe(true)

            connection.query("SELECT 1", (err, resultset) => {
                expect(err).toBeNull()
                expect(resultset).toBeInstanceOf(Vertica.Resultset)
                expect(connection.busy).toBe(false)
                expect(connection.connected).toBe(true)
                done()
            })
        })
    }))
})
