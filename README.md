# 🐳 Docker Multi-Stage Build — Go Web Application

<div align="center">

![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Go](https://img.shields.io/badge/Go_1.21-00ADD8?style=for-the-badge&logo=go&logoColor=white)
![Alpine](https://img.shields.io/badge/Alpine_3.19-0D597F?style=for-the-badge&logo=alpinelinux&logoColor=white)
![MacOS](https://img.shields.io/badge/Tested_on-macOS-000000?style=for-the-badge&logo=apple&logoColor=white)

<br/>

**A hands-on project demonstrating Docker Multi-Stage Builds with a Go web application.**
**Shows exactly how multi-stage builds reduce image size by 98.3% in real output.**

<br/>

*Built by [Akshay Sawant](mailto:akshaysawant9009@gmail.com) — AWS DevOps Engineer | Hinjawadi, Pune*

---

### 🏆 Final Result — Real Docker Output

```
IMAGE              DISK USAGE    CONTENT SIZE    BUILD TYPE
─────────────────────────────────────────────────────────────
go-single:latest    1.29 GB        306 MB       ❌ Single-Stage
go-multi:latest     21.9 MB        7.04 MB      ✅ Multi-Stage
─────────────────────────────────────────────────────────────
                  ↓ 98.3% smaller with Multi-Stage Build
```

</div>

---

## 📌 Table of Contents

- [What is Multi-Stage Build?](#-what-is-multi-stage-build)
- [Why Does Image Size Matter?](#-why-does-image-size-matter)
- [Project Structure](#-project-structure)
- [The Go Application](#-the-go-application)
- [Stage 1 — Single-Stage Dockerfile](#-stage-1--single-stage-dockerfile)
- [Stage 2 — Multi-Stage Dockerfile](#-stage-2--multi-stage-dockerfile)
- [How Multi-Stage Works — Visual](#-how-multi-stage-works--visual)
- [Step-by-Step Terminal Commands](#-step-by-step-terminal-commands)
- [Real Terminal Output](#-real-terminal-output)
- [Size Comparison — Final Result](#-size-comparison--final-result)
- [Run & Test Locally](#-run--test-locally)
- [Clone This Project](#-clone-this-project)
- [Key Learnings](#-key-learnings)
- [Push to GitHub](#-push-to-github)

---

## 🧠 What is Multi-Stage Build?

> **Multi-Stage Build = Build the app in one image → Ship only the result in a tiny image.**

In a normal (single-stage) Dockerfile, everything used to **build** the app stays inside the final image — the Go compiler, build tools, source code, all of it. You don't need any of that to **run** the app.

A **multi-stage Dockerfile** solves this with two separate stages:

```
┌─────────────────────────────────┐      ┌─────────────────────────┐
│       STAGE 1: BUILDER          │      │    STAGE 2: RUNNER      │
│                                 │      │                         │
│  Base:  golang:1.21 (full)      │      │  Base: alpine:3.19      │
│  Has:   Go compiler             │      │  Has:  Nothing extra    │
│         Build tools             │  ──► │                         │
│         Source code             │ copy │  Gets: Only the         │
│         Dependencies            │ only │  compiled binary        │
│                                 │ this │  ( hello )              │
│  Size:  1.29 GB ❌              │      │                         │
└─────────────────────────────────┘      │  Size:  21.9 MB ✅      │
                                         └─────────────────────────┘
```

**The key line that makes this work:**
```dockerfile
COPY --from=builder /app/hello .
```
This copies **only the compiled binary** from Stage 1 into Stage 2. The Go compiler and all build tools are discarded automatically.

---

## 📦 Why Does Image Size Matter?

| Problem | Impact |
|---------|--------|
| 🐢 Large images take longer to pull | Slower deployments, slower CI/CD |
| 💰 Large images cost more storage | Higher AWS ECR / DockerHub costs |
| 🔒 More packages = more CVEs | Larger attack surface, security risk |
| 🚀 Small images start faster | Better Kubernetes pod startup time |
| 🌐 Slow push/pull in pipelines | Slower Jenkins/GitHub Actions builds |

> **In production at scale:** If you deploy 100 containers per day, a 1.3 GB image vs 22 MB image means the difference between minutes and seconds per deployment — and significant cost savings on bandwidth and storage.

---

## 📁 Project Structure

```
Go-App/
│
├── 📄 main.go             ← Go web application (HTTP server on port 8080)
├── 📄 dockerfile          ← Multi-Stage Dockerfile  ✅ (production)
├── 📄 dockerfile.single   ← Single-Stage Dockerfile ❌ (for comparison only)
└── 📄 README.md           ← This documentation
```

---

## 🟦 The Go Application

**File:** `main.go`

```go
package main

import (
    "fmt"
    "net/http"
)

func main() {
    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        fmt.Fprintf(w, "Hello World from Go Web App!")
    })

    fmt.Println("Server running on port 8080")
    http.ListenAndServe(":8080", nil)
}
```

**What it does:**
- Starts an HTTP server on **port 8080**
- Responds with `Hello World from Go Web App!` on every request
- Simple, lightweight — perfect for demonstrating the size impact

---

## ❌ Stage 1 — Single-Stage Dockerfile

**File:** `dockerfile.single`

```dockerfile
FROM golang:1.21
WORKDIR /app
COPY . .
RUN go build -o hello main.go
EXPOSE 8080
CMD ["./hello"]
```

### Line-by-Line Explanation:

| Line | Command | What It Does |
|------|---------|-------------|
| 1 | `FROM golang:1.21` | Pulls the full Go image — **1.29 GB** includes compiler, tools, OS |
| 2 | `WORKDIR /app` | Sets `/app` as the working directory inside the container |
| 3 | `COPY . .` | Copies all project files from host into container |
| 4 | `RUN go build -o hello main.go` | Compiles Go code → creates binary named `hello` |
| 5 | `EXPOSE 8080` | Documents that the container listens on port 8080 |
| 6 | `CMD ["./hello"]` | Runs the compiled binary when container starts |

### ⚠️ The Problem:

```
The final image contains:
  ✅ hello (the binary we actually need — ~7 MB)
  ❌ Go compiler         (~300 MB — not needed at runtime)
  ❌ Go standard library (~200 MB — not needed at runtime)
  ❌ Build tools         (~100 MB — not needed at runtime)
  ❌ Full Debian OS      (~600 MB — not needed at runtime)
  ──────────────────────────────────────────────────────
  Total: 1.29 GB   (we only needed 7 MB!)
```

**Result:** `go-single:latest` → **1.29 GB** ❌

---

## ✅ Stage 2 — Multi-Stage Dockerfile

**File:** `dockerfile`

```dockerfile
# ─────────────────────────────────────────────
# Stage 1: BUILD STAGE
# Uses full golang image to compile the binary
# ─────────────────────────────────────────────
FROM golang:1.21 AS builder
WORKDIR /app
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o hello main.go

# ─────────────────────────────────────────────
# Stage 2: RUN STAGE
# Uses minimal alpine image — no Go tools needed
# Only copies the compiled binary from Stage 1
# ─────────────────────────────────────────────
FROM alpine:3.19
WORKDIR /app
COPY --from=builder /app/hello .
EXPOSE 8080
CMD ["./hello"]
```

### Line-by-Line Explanation:

**Stage 1 — Builder:**

| Line | Command | What It Does |
|------|---------|-------------|
| 1 | `FROM golang:1.21 AS builder` | Full Go image, named `builder` so Stage 2 can reference it |
| 2 | `WORKDIR /app` | Sets working directory |
| 3 | `COPY . .` | Copies source code |
| 4 | `CGO_ENABLED=0` | Disables C bindings → creates a **pure static binary** |
| 4 | `GOOS=linux` | Cross-compiles for Linux (important if building on macOS) |
| 4 | `go build -o hello main.go` | Compiles into static binary named `hello` |

> 🔑 `CGO_ENABLED=0` is the critical flag here. It tells Go to produce a **fully static binary** with zero external library dependencies — so it can run even on Alpine which uses `musl libc` instead of `glibc`.

**Stage 2 — Runner:**

| Line | Command | What It Does |
|------|---------|-------------|
| 1 | `FROM alpine:3.19` | Minimal 5 MB Alpine base image — no Go tools at all |
| 2 | `WORKDIR /app` | Sets working directory in the new clean image |
| 3 | `COPY --from=builder /app/hello .` | ⭐ Copies **only the binary** from Stage 1 |
| 4 | `EXPOSE 8080` | Documents the port |
| 5 | `CMD ["./hello"]` | Runs the binary |

**Result:** `go-multi:latest` → **21.9 MB** ✅

---

## 🎬 How Multi-Stage Works — Visual

```
docker build -t go-multi .
         │
         ▼
┌────────────────────────────────────────────────────────────────┐
│  STAGE 1 — "builder"                                           │
│                                                                │
│  golang:1.21 (1.29 GB)                                         │
│       ↓                                                        │
│  COPY main.go                                                  │
│       ↓                                                        │
│  go build → creates  /app/hello  (7 MB static binary)         │
│                           │                                    │
│  Everything else in       │  ← Only this crosses over         │
│  this stage is DISCARDED  │                                    │
└───────────────────────────┼────────────────────────────────────┘
                            │
                            ▼  COPY --from=builder /app/hello .
┌────────────────────────────────────────────────────────────────┐
│  STAGE 2 — final image                                         │
│                                                                │
│  alpine:3.19 (5 MB)                                            │
│       +                                                        │
│  hello binary (7 MB)                                           │
│       =                                                        │
│  go-multi:latest  →  21.9 MB  ✅                               │
└────────────────────────────────────────────────────────────────┘
```

---

## 💻 Step-by-Step Terminal Commands

Follow these exact steps to reproduce the project on your machine:

### Step 1 — Create Project Folder

```bash
mkdir Go-App
cd Go-App
```

### Step 2 — Create the Go Application

```bash
# Create main.go
cat > main.go << 'EOF'
package main

import (
    "fmt"
    "net/http"
)

func main() {
    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        fmt.Fprintf(w, "Hello World from Go Web App!")
    })

    fmt.Println("Server running on port 8080")
    http.ListenAndServe(":8080", nil)
}
EOF

# Verify the file
cat main.go
```

### Step 3 — Create Single-Stage Dockerfile

```bash
cat > dockerfile.single << 'EOF'
FROM golang:1.21
WORKDIR /app
COPY . .
RUN go build -o hello main.go
EXPOSE 8080
CMD ["./hello"]
EOF
```

### Step 4 — Build Single-Stage Image

```bash
docker build -t go-single -f dockerfile.single .
```

### Step 5 — Check Image Size (Single-Stage)

```bash
docker images go-single
```

Expected output:
```
IMAGE            ID              DISK USAGE    CONTENT SIZE
go-single:latest dbda5957a9c3    1.29GB        306MB
```

### Step 6 — Create Multi-Stage Dockerfile

```bash
cat > dockerfile << 'EOF'
FROM golang:1.21 AS builder
WORKDIR /app
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o hello main.go

FROM alpine:3.19
WORKDIR /app
COPY --from=builder /app/hello .
EXPOSE 8080
CMD ["./hello"]
EOF
```

### Step 7 — Build Multi-Stage Image

```bash
docker build -t go-multi .
```

### Step 8 — Compare Both Images

```bash
docker images | grep go-
```

Expected output:
```
IMAGE              ID             DISK USAGE   CONTENT SIZE
go-multi:latest    99f3d38b60f6       21.9MB         7.04MB
go-single:latest   dbda5957a9c3       1.29GB          306MB
```

### Step 9 — Run Both Containers Side by Side

```bash
# Run single-stage on port 8081
docker run -d --name go-single-app -p 8081:8080 go-single

# Run multi-stage on port 8082
docker run -d --name go-multi-app  -p 8082:8080 go-multi

# Verify both are running
docker ps
```

Expected output:
```
CONTAINER ID  IMAGE      COMMAND    CREATED        STATUS        PORTS                     NAMES
2bc41d60f9e8  go-multi   "./hello"  7 seconds ago  Up 6 seconds  0.0.0.0:8082->8080/tcp    go-multi-app
0b2932c5193d  go-single  "./hello"  9 minutes ago  Up 9 minutes  0.0.0.0:8081->8080/tcp    go-single-app
```

---

## 📟 Real Terminal Output

Here is the actual terminal session from this project:

```bash
# ── Create and navigate to folder ──────────────────────────────────
indrasurya@akshays-MacBook-Air docker % mkdir Go-App
indrasurya@akshays-MacBook-Air docker % cd Go-App

# ── Create Go application ──────────────────────────────────────────
indrasurya@akshays-MacBook-Air Go-App % vim main.go
indrasurya@akshays-MacBook-Air Go-App % cat main.go
package main

import (
    "fmt"
    "net/http"
)

func main() {
    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        fmt.Fprintf(w, "Hello World from Go Web App!")
    })

    fmt.Println("Server running on port 8080")
    http.ListenAndServe(":8080", nil)
}

# ── Build Single-Stage image ───────────────────────────────────────
indrasurya@akshays-MacBook-Air Go-App % docker build -t go-single .
[+] Building ... FINISHED

# ── Check size — single-stage ──────────────────────────────────────
IMAGE                 ID              DISK USAGE    CONTENT SIZE
go-single:latest      dbda5957a9c3      1.29GB          306MB

# ── Build Multi-Stage image ────────────────────────────────────────
indrasurya@akshays-MacBook-Air Go-App % docker build -t go-multi .
[+] Building ... FINISHED

# ── Compare both images ────────────────────────────────────────────
IMAGE                 ID              DISK USAGE    CONTENT SIZE
go-multi:latest       99f3d38b60f6       21.9MB         7.04MB   ✅
go-single:latest      dbda5957a9c3       1.29GB          306MB   ❌

# ── Run both containers ────────────────────────────────────────────
indrasurya@akshays-MacBook-Air Go-App % docker run -d --name go-single-app -p 8081:8080 go-single
0b2932c5193d...

indrasurya@akshays-MacBook-Air Go-App % docker run -d --name go-multi-app -p 8082:8080 go-multi
2bc41d60f9e8...

# ── Both containers running ────────────────────────────────────────
CONTAINER ID   IMAGE      COMMAND    PORTS                       NAMES
2bc41d60f9e8   go-multi   "./hello"  0.0.0.0:8082->8080/tcp     go-multi-app
0b2932c5193d   go-single  "./hello"  0.0.0.0:8081->8080/tcp     go-single-app
```

---

## 📊 Size Comparison — Final Result

```
Single-Stage Build:
go-single:latest
████████████████████████████████████████████████████  1.29 GB

Multi-Stage Build:
go-multi:latest
█  21.9 MB

──────────────────────────────────────────────────────────────
Size Reduction:   1.29 GB  →  21.9 MB   =  98.3% smaller ✅
──────────────────────────────────────────────────────────────
```

| Metric | Single-Stage | Multi-Stage | Improvement |
|--------|-------------|-------------|-------------|
| Disk Usage | 1.29 GB | 21.9 MB | **98.3% smaller** |
| Content Size | 306 MB | 7.04 MB | **97.7% smaller** |
| Pull Time | ~minutes | ~seconds | Much faster |
| Attack Surface | Full OS + Go tools | Alpine only | Much safer |
| CVE Vulnerabilities | Many | Minimal | More secure |

---

## 🚀 Run & Test Locally

Once both containers are running:

```bash
# Test Single-Stage container
curl http://localhost:8081
# Output: Hello World from Go Web App!

# Test Multi-Stage container
curl http://localhost:8082
# Output: Hello World from Go Web App!
```

Or open in browser:
- 🌐 Single-Stage app: [http://localhost:8081](http://localhost:8081)
- 🌐 Multi-Stage app:  [http://localhost:8082](http://localhost:8082)

Both return the **same response** — same app, completely different image sizes.

```bash
# Clean up containers after testing
docker stop go-single-app go-multi-app
docker rm   go-single-app go-multi-app
```

---

## 📥 Clone This Project

```bash
# Clone the repository
git clone https://github.com/social9009/Go-App.git
cd Go-App

# Check the files
ls -la
# main.go  dockerfile  dockerfile.single  README.md

# Build multi-stage image
docker build -t go-multi .

# Run it
docker run -d --name go-multi-app -p 8082:8080 go-multi

# Test it
curl http://localhost:8082
```

---

## 💡 Key Learnings

### ✅ What Multi-Stage Solves

```
Single-Stage Problem:
  golang:1.21 image is needed to COMPILE the code.
  But it's 1.29 GB and has no role at RUNTIME.
  Without multi-stage, you're forced to ship the compiler with the app.

Multi-Stage Solution:
  Stage 1: Use golang:1.21 to compile → produces hello binary (7 MB)
  Stage 2: Use alpine:3.19 (5 MB) + copy only hello binary
  Result:  21.9 MB final image — compiler never ships to production
```

### ⭐ The Critical Flags Explained

```bash
CGO_ENABLED=0   # Disables C bindings
                # Without this, Go binary links to glibc
                # Alpine uses musl libc → binary would crash
                # With CGO_ENABLED=0 → fully static binary → runs anywhere

GOOS=linux      # Cross-compile target OS = Linux
                # Required when building on macOS for Linux containers
                # Without this → binary may not run inside Linux container
```

### ⚠️ Common Mistakes to Avoid

```
❌ MISTAKE: Forgetting CGO_ENABLED=0
   Result:  Container starts then immediately exits (exit code 1)
            Binary compiled against glibc, Alpine has musl — incompatible
   FIX:     Always set CGO_ENABLED=0 when targeting Alpine

❌ MISTAKE: Typo in COPY --from
   Wrong:   COPY --form=builder /app/hello .   (typo: form instead of from)
   Correct: COPY --from=builder /app/hello .

❌ MISTAKE: Not naming Stage 1 with AS
   Wrong:   FROM golang:1.21
   Correct: FROM golang:1.21 AS builder
   (Without AS, you can't reference Stage 1 in COPY --from)

❌ MISTAKE: Wrong binary path in COPY
   Wrong:   COPY --from=builder /hello .        (binary is in /app/hello)
   Correct: COPY --from=builder /app/hello .
```

### 🏆 When to Use Multi-Stage Builds

| Language | Use Multi-Stage? | Stage 1 Base | Stage 2 Base |
|----------|-----------------|-------------|-------------|
| **Go** | ✅ Always | `golang:1.21` | `alpine` or `scratch` |
| **Java** | ✅ Yes | `maven:3-jdk-17` | `eclipse-temurin:17-jre` |
| **Node.js** | ✅ Yes | `node:18` | `node:18-alpine` |
| **Python** | ⚠️ Sometimes | `python:3.11` | `python:3.11-slim` |
| **Rust** | ✅ Always | `rust:1.75` | `scratch` or `alpine` |

---

## 🔗 Related Projects

[![SonarQube](https://img.shields.io/badge/Project-SonarQube_CI/CD-4E9BCD?style=for-the-badge&logo=sonarqube)](https://github.com/social9009/SonarQube-Project)
[![Docker Image Types](https://img.shields.io/badge/Project-Docker_Image_Types-2496ED?style=for-the-badge&logo=docker)](https://github.com/social9009/docker-image-types)
[![Portfolio](https://img.shields.io/badge/Project-Portfolio_Website-00D4FF?style=for-the-badge&logo=html5)](https://github.com/social9009/portfolio)

---

## 👨‍💻 Author

**Akshay Sawant** — AWS DevOps Engineer | AWS Solutions Architect Associate

[![Email](https://img.shields.io/badge/Email-akshaysawant9009@gmail.com-D14836?style=flat-square&logo=gmail)](mailto:akshaysawant9009@gmail.com)
[![GitHub](https://img.shields.io/badge/GitHub-social9009-181717?style=flat-square&logo=github)](https://github.com/social9009)
[![Location](https://img.shields.io/badge/Location-Hinjawadi_Pune-4285F4?style=flat-square&logo=googlemaps)](https://maps.google.com)

---

<div align="center">

⭐ **Star this repo if it helped you understand Docker Multi-Stage Builds!** ⭐

*Part of my DevOps learning series — Docker, Jenkins, SonarQube, AWS, Kubernetes*

</div>
