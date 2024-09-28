'use client';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Avatar, AvatarImage } from '@/components/ui/avatar';
import { useEffect, useState, useRef } from 'react';

export default function OurTeam() {
  const [isVisible, setIsVisible] = useState(false);
  const sectionRef = useRef(null);

  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          setIsVisible(entry.isIntersecting);
        });
      },
      {
        threshold: 0.35,
      },
    );

    if (sectionRef.current) {
      observer.observe(sectionRef.current);
    }

    return () => {
      if (sectionRef.current) {
        observer.unobserve(sectionRef.current);
      }
    };
  }, []);

  return (
    <section
      ref={sectionRef}
      className={`max-w-[1500px] mx-auto transition-all duration-500 ${
        isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-10'
      }`}
    >
      <Card className='bg-[#F6F6F6]'>
        <CardHeader>
          <CardTitle className='text-5xl font-normal my-10 mx-auto'>
            Команда \\\ Dream team
          </CardTitle>
        </CardHeader>
        <CardContent className='grid grid-cols-3 mb-20'>
          <div className='bg-card px-10 py-7 rounded-2xl mx-auto'>
            <Avatar className='w-[232px] h-[232px]'>
              <AvatarImage src='/avatars/1.png' />
            </Avatar>
            <div className='space-y-3'>
              <p className='text-5xl text-center'>stamp_qw</p>
              <p className='text-muted-foreground text-center'>founder\\\ full-stack developer</p>
            </div>
          </div>
          <div className='bg-card px-10 py-7 rounded-2xl mx-auto'>
            <Avatar className='w-[232px] h-[232px]'>
              <AvatarImage src='/avatars/2.png' />
            </Avatar>
            <div className='space-y-3'>
              <p className='text-5xl text-center'>gladiator</p>
              <p className='text-muted-foreground text-center'>founder\\\ back-end\\\ devops</p>
            </div>
          </div>
          <div className='bg-card px-10 py-7 rounded-2xl mx-auto'>
            <Avatar className='w-[232px] h-[232px]'>
              <AvatarImage src='/avatars/3.jpg' className='object-cover' />
            </Avatar>
            <div className='space-y-3'>
              <p className='text-5xl text-center'>LL33ch</p>
              <p className='text-muted-foreground text-center'>front-end developer</p>
            </div>
          </div>
        </CardContent>
      </Card>
    </section>
  );
}
