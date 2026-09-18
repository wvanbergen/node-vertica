const assert = require('assert')
const {EventEmitter} = require('events')
const net = require('net')
const Connection = require('../../lib/connection')
const Query = require('../../lib/query')

function fixture() {
    const connection = new Connection({ssl: false})
    const socket = new EventEmitter()
    socket.writes = []
    socket.write = data => socket.writes.push(data)
    socket.end = () => { socket.ends = (socket.ends || 0) + 1 }
    socket.destroy = () => { socket.destroys = (socket.destroys || 0) + 1 }
    connection.connection = socket
    connection.connected = true
    connection.busy = false
    return {connection, socket}
}
const tick = () => new Promise(resolve => setImmediate(resolve))

function asyncTest(fn) {
    return function (done) { fn().then(() => done(), done) }
}

describe('connection terminal lifecycle', function () {
    it('sends one termination frame and rejects work after disconnect', asyncTest(async function () {
        const {connection, socket} = fixture()
        connection.disconnect()
        connection.disconnect()
        assert.strictEqual(socket.writes.length, 1)
        assert.strictEqual(socket.writes[0][0], 'X'.charCodeAt(0))
        assert.strictEqual(socket.ends, 1)
        let calls = 0
        connection.query('select 1', err => { assert.ok(err); calls++ })
        await tick()
        assert.strictEqual(calls, 1)
        assert.strictEqual(connection.queue.length, 0)
    }))

    for (const event of ['close', 'error', 'timeout', 'disconnect', 'destroy']) {
        it(`settles active and queued work once after ${event} followed by close`, asyncTest(async function () {
            const {connection} = fixture()
            connection.on('error', () => {})
            const calls = [0, 0, 0]
            connection.query('select 1', err => { assert.ok(err); calls[0]++ })
            connection.query('select 2', err => { assert.ok(err); calls[1]++ })
            const streaming = connection.query('select 3')
            streaming.on('error', err => { assert.ok(err); calls[2]++ })
            if (event === 'error') connection._onError(new Error('broken'))
            else if (event === 'close') connection._onClose()
            else if (event === 'timeout') connection._onTimeout()
            else connection[event]()
            connection._onClose()
            connection._onClose()
            await tick()
            assert.deepStrictEqual(calls, [1, 1, 1])
            assert.strictEqual(connection.queue.length, 0)
            assert.strictEqual(connection.currentJob, false)
        }))
    }

    it('settles connect once if the transport closes during startup', asyncTest(async function () {
        const original = net.createConnection
        const {socket} = fixture()
        net.createConnection = () => socket
        try {
            let calls = 0
            const connection = new Connection({ssl: false})
            connection.connect(err => { assert.ok(err); calls++ })
            socket.emit('error', new Error('refused'))
            socket.emit('close')
            assert.strictEqual(calls, 1)
            assert.strictEqual(socket.destroys, 1)
        } finally { net.createConnection = original }
        await tick()
    }))

    it('does not report an established connection error to its connect callback', function () {
        const {connection} = fixture()
        let connects = 0
        let errors = 0
        connection.connectedCallback = err => { assert.ifError(err); connects++ }
        connection.on('error', () => errors++)
        connection._initializationSuccess()
        connection._onError(new Error('broken'))
        connection._onClose()
        assert.strictEqual(connects, 1)
        assert.strictEqual(errors, 1)
    })

    it('does not complete a query twice on late terminal events', asyncTest(async function () {
        const {connection} = fixture()
        let calls = 0
        const query = new Query(connection, 'select 1', () => calls++)
        query.onConnectionError(new Error('closed'))
        query.onReadyForQuery({})
        query.onConnectionError(new Error('again'))
        await tick()
        assert.strictEqual(calls, 1)
    }))

    it('fails an active query before a late ReadyForQuery can report success', asyncTest(async function () {
        const {connection} = fixture()
        let calls = 0
        connection.query('select 1', err => { assert.ok(err); calls++ })
        connection.destroy()
        connection.emit('ReadyForQuery', {})
        await tick()
        assert.strictEqual(calls, 1)
    }))

    it('confirms closure only on the socket close event', function () {
        const {connection, socket} = fixture()
        socket.once('close', connection._onClose.bind(connection))
        let closes = 0
        connection.on('close', () => closes++)
        connection.destroy()
        assert.strictEqual(closes, 0)
        socket.emit('close')
        assert.strictEqual(closes, 1)
    })
})
