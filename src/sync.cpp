// Copyright (c) 2011-2015 The Bitcoin Core developers
// Copyright (c) 2015-2019 The Bitcoin Unlimited developers
// Distributed under the MIT software license, see the accompanying
// file COPYING or http://www.opensource.org/licenses/mit-license.php.

#include "sync.h"

#include "util.h"
#include "utilstrencodings.h"

#include <boost/thread/tss.hpp> // for boost::thread_specific_ptr
#include <stdio.h>
#include <thread>

#ifdef DEBUG_LOCKCONTENTION
void PrintLockContention(const char *pszName, const char *pszFile, unsigned int nLine)
{
    LOGA("LOCKCONTENTION: %s\n", pszName);
    LOGA("Locker: %s:%d\n", pszFile, nLine);
}
#endif /* DEBUG_LOCKCONTENTION */

#ifdef DEBUG_LOCKORDER

#ifdef __linux__
#include <sys/syscall.h>
uint64_t getTid(void)
{
    // "native" thread id used so the number correlates with what is shown in gdb
    pid_t tid = (pid_t)syscall(SYS_gettid);
    return tid;
}
#else
#include <functional>
uint64_t getTid(void)
{
    // Note: there is no guaranteed way to turn the thread-id into an int
    // since it's an opaque type. Just about the only operation it supports
    // is std::hash (so that thread id's may be placed in maps).
    // So we just do this.
    static std::hash<std::thread::id> hasher;
    return uint64_t(hasher(std::this_thread::get_id()));
}
#endif

void EnterCritical(const char *pszName, const char *pszFile, unsigned int nLine, void *cs, bool fTry)
{
}
void LeaveCritical()
{
}
void DeleteCritical(const void *cs)
{
}

void AssertLockHeldInternal(const char *pszName, const char *pszFile, unsigned int nLine, void *cs)
{

}

void AssertLockNotHeldInternal(const char *pszName, const char *pszFile, unsigned int nLine, void *cs)
{

}

void AssertWriteLockHeldInternal(const char *pszName,
    const char *pszFile,
    unsigned int nLine,
    CSharedCriticalSection *cs)
{
    if (cs->try_lock()) // It would be better to check that this thread has the lock
    {
        fprintf(stderr, "Assertion failed: lock %s not held in %s:%i; locks held:\n%s", pszName, pszFile, nLine,
            LocksHeld().c_str());
        fflush(stderr);
        abort();
    }
}

void AssertRecursiveWriteLockHeldInternal(const char *pszName,
    const char *pszFile,
    unsigned int nLine,
    CRecursiveSharedCriticalSection *cs)
{
    if (cs->try_lock()) // It would be better to check that this thread has the lock
    {
        fprintf(stderr, "Assertion failed: lock %s not held in %s:%i; locks held:\n%s", pszName, pszFile, nLine,
            LocksHeld().c_str());
        fflush(stderr);
        abort();
    }
}

// BU normally CCriticalSection is a typedef, but when lockorder debugging is on we need to delete the critical
// section from the lockorder map
#ifdef DEBUG_LOCKORDER
CCriticalSection::CCriticalSection() : name(nullptr) {}
CCriticalSection::CCriticalSection(const char *n) : name(n)
{
// print the address of named critical sections so they can be found in the mutrace output
#ifdef ENABLE_MUTRACE
    if (name)
    {
        printf("CCriticalSection %s at %p\n", name, this);
        fflush(stdout);
    }
#endif
}

CCriticalSection::~CCriticalSection()
{
#ifdef ENABLE_MUTRACE
    if (name)
    {
        printf("Destructing %s\n", name);
        fflush(stdout);
    }
#endif
    DeleteCritical((void *)this);
}
#endif

// BU normally CSharedCriticalSection is a typedef, but when lockorder debugging is on we need to delete the critical
// section from the lockorder map
#ifdef DEBUG_LOCKORDER
CSharedCriticalSection::CSharedCriticalSection() : name(nullptr) {}
CSharedCriticalSection::CSharedCriticalSection(const char *n) : name(n)
{
// print the address of named critical sections so they can be found in the mutrace output
#ifdef ENABLE_MUTRACE
    if (name)
    {
        printf("CSharedCriticalSection %s at %p\n", name, this);
        fflush(stdout);
    }
#endif
}

CSharedCriticalSection::~CSharedCriticalSection()
{
#ifdef ENABLE_MUTRACE
    if (name)
    {
        printf("Destructing CSharedCriticalSection %s\n", name);
        fflush(stdout);
    }
#endif
    DeleteCritical((void *)this);
}
#endif


#endif /* DEBUG_LOCKORDER */
