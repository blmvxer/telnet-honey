import strutils, net, os

var
  command: string
  curDir: string
  line: string
  dirLine: string
  dirList: string
  dirListAll: string
  secretFile: string
  server: Socket = newSocket()
  client: Socket = new(Socket)
  cmdLog = open("honeyLogs/telnet.log", fmWrite)
  loginLog = open("honeyLogs/login.log", fmWrite)
  secretText = open("honeyFiles/secret.txt", fmRead)
  clientAddr: string


proc runServer() =
  server.setSockOpt(OptReuseAddr, true)
  server.bindAddr(Port(23))
  server.listen()
  stdout.writeLine("[!] Starting telnetHoney...\n\n")
  stdout.writeLine("[+] Listening for new connections on port 23...")
  server.accept(client)
  client.send("""
Nim Telnet Server
    v 1.3.1p3
""")

proc getDirConf(getDir: string) =
  var dirConf = open("honeyFiles/directory.conf", fmRead)
  dirLine = ("dir=" & getDir)
  curDir = getDir
  while true:
    try:
      line = readLine(dirConf)
      if line.contains("#"):
        discard
      elif (line) == (dirLine):
        dirList = (readLine(dirConf).replace("dirCont=", "") & "\n")
        dirListAll = (readLine(dirConf).replace("dirContAll=", "") & "\n")
        secretFile = (readLine(dirConf).replace("secretFile=", ""))
      else:
        discard line
    except EOFError:
      break

#proc getPass(prompt: cstring) : cstring {.header: "<unistd.h>", importc: "getpass".}

proc shell() =
  getDirConf("home")
  while true:
    client.send("$ ")
    command = client.recvLine()
    cmdLog.write($getPeerAddr(client) & " -- " &  command & "\n")
    if command.contains("ls"):
      if command.contains(" -a"):
        getDirConf(curDir)
        client.send(dirListAll)
      else:
        getDirConf(curDir)
        client.send(dirList)
    elif command == "exit":
      close(client)
      stdout.writeLine("[!] Client disconnected...closing server")
      close(server)
      quit(0)
    elif command.contains("cd "):
      if command == "cd ../":
        if curDir != "home":
          getDirConf("home")
        else:
          client.send("Command not allowed\n")
      else:
        getDirConf(command.replace("cd ", ""))
    elif command.contains("cat "):
      getDirConf(curDir)
      if secretFile != "":
        try:
          while true:
            client.send(readLine(secretText) & "\n")
        except EOFError:
          continue
    else:
      client.send("Command not allowed\n")

proc login(): bool =
  sleep(10000)
  clientAddr = $getPeerAddr(client)
  stdout.writeLine("[+]: client connected " & clientAddr)
  client.send("Username:")
  let user: string = client.recvLine()
  if user == "":
    discard
  client.send("Password:")
  let pass: string = client.recvLine()
  if pass == "":
    discard
  if user.contains("admin") and pass == "admin":
    return true
  else:
    loginLog.write(clientAddr & " -- " & user & ":" & pass  & "\n")
    return false


proc main() = 
  try:
    runServer()
  except OSError:
    sleep(5000)
    runServer()

  var
    attempts: int

  attempts = 0

  while attempts != 3:
    if login() != true:
      stdout.writeLine("[!] Client login failed")
      client.send("Login incorrect\n\n")
      attempts = attempts + 1
    else:
      stdout.writeLine("[!] Client logged in")
      client.send("\nLogin accepted\n")
      shell()
main()
quit(0)
