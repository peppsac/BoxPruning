///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/**
 *	Contains profiling code.
 *	\file		IceProfiler.h
 *	\author		Pierre Terdiman
 *	\date		April, 4, 2000
 */
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Include Guard
#ifndef __ICEPROFILER_H__
#define __ICEPROFILER_H__

	#ifdef LINUX
	// http://wiki.osdev.org/Inline_Assembly/Examples#CPUID
	static inline void cpuid(int code, uint32_t* a, uint32_t* d)
	{
	    asm volatile ( "cpuid" : "=a"(*a), "=d"(*d) : "0"(code) : "ebx", "ecx" );
	}

	static inline uint64_t rdtsc()
	{
	    uint64_t ret;
	    #if 0
	    asm volatile ( "rdtsc" : "=A"(ret) );
		#else
	    unsigned int lo,hi;
	    __asm__ __volatile__ ("rdtsc" : "=a" (lo), "=d" (hi));
	    ret = ((uint64_t)hi << 32) | lo;
	    #endif

	    return ret;

	}
	#endif



	FUNCTION ICECORE_API void		SetBaseTime(uint64_t time);
	FUNCTION ICECORE_API uint64_t	GetBaseTime();

	//! This function initializes the profiler by counting the cpuid overhead.
	//! This is done 3 times on purpose, since cpuid takes a longer time to execute the first times it's called.
	//! "cpuid" is used before rdtsc to prevent out-of-sequence execution from producing wrong results.
	//! For more details, read Intel's application notes "Using the RDTSC instruction for performance monitoring".
	//!	\see		StartProfile
	//!	\see		EndProfile
	inline_ void InitProfiler()
	{
		#if LINUX
		uint32_t dont, care;
		cpuid(0, &dont, &care);
		rdtsc();
		rdtsc();
		SetBaseTime(rdtsc());
		#else
		udword cyc, Base;
		_asm{
			cpuid
			rdtsc
			mov		cyc, eax
			cpuid
			rdtsc
			sub		eax, cyc
			mov		Base, eax

			cpuid
			rdtsc
			mov		cyc, eax
			cpuid
			rdtsc
			sub		eax, cyc
			mov		Base, eax

			cpuid
			rdtsc
			mov		cyc, eax
			cpuid
			rdtsc
			sub		eax, cyc
			mov		Base, eax
		}
		SetBaseTime(Base);
		#endif
	}

	//!	This function starts recording the number of cycles elapsed.
	//!	\param		val		[out] address of a 32 bits value where the system should store the result.
	//!	\see		EndProfile
	//!	\see		InitProfiler
	inline_ void	StartProfile(uint64_t& val)
	{
		#if LINUX
		val = rdtsc();
		#else
		__asm{
			cpuid
			rdtsc
			mov		ebx, val
			mov		[ebx], eax
		}
		#endif
	}

	//!	This function ends recording the number of cycles elapsed.
	//!	\param		val		[out] address to store the number of cycles elapsed since the last StartProfile.
	//!	\see		StartProfile
	//!	\see		InitProfiler
	inline_ void	EndProfile(uint64_t& val)
	{
		#if LINUX
		val = (rdtsc() - val) - GetBaseTime();
		#else
		__asm{
			cpuid
			rdtsc
			mov		ebx, val
			sub		eax, [ebx]
			mov		[ebx], eax
		}
		val-=GetBaseTime();
		#endif
	}

#endif // __ICEPROFILER_H__
