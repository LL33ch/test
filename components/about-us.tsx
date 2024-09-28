'use client';
import { Card, CardContent } from '@/components/ui/card';
import { useEffect, useState, useRef } from 'react';

export default function AboutUs() {
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
        threshold: 0.5,
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
    <section className='bg-gradient-to-t from-[#0500FF33] to-transparent'>
      <div
        ref={sectionRef}
        className={`max-w-[1500px] mx-auto pb-40 transition-all duration-500 ease-in-out ${
          isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-10'
        }`}
      >
        <p className='text-3xl text-center mb-10'>О нас</p>
        <Card className='bg-[#F6F6F6]'>
          <CardContent className='grid grid-cols-2 text-center items-stretch gap-10 p-14'>
            <div className='w-full px-10 py-7 rounded-2xl space-y-3 mx-auto bg-[#D9D9D9]'>
              <p className='text-9xl'>🤓</p>
              <p className='text-4xl'>Команда основана в 2019 году</p>
              <p className='text-2xl text-muted-foreground'>
                Сначала это были маленькие пет проекты
              </p>
            </div>
            <div className='w-full px-10 py-7 rounded-2xl space-y-3 mx-auto bg-[#D9D9D9]'>
              <p className='text-9xl'>🥳</p>
              <p className='text-4xl'>Старт фриланс карьеры в 2020</p>
              <p className='text-2xl text-muted-foreground'>
                Начали брать мелкие заказы на фриланс
              </p>
            </div>
            <div className='w-full px-10 py-7 rounded-2xl space-y-3 mx-auto bg-[#D9D9D9]'>
              <p className='text-9xl'>🚀</p>
              <p className='text-4xl'>Набор сотрудников в команду</p>
              <p className='text-2xl text-muted-foreground'>
                В настоящее время расширяем состав команды
              </p>
            </div>
            <div className='w-full px-10 py-7 rounded-2xl space-y-3 mx-auto bg-[#D9D9D9]'>
              <p className='text-9xl'>📈</p>
              <p className='text-4xl'>Работа с большими компаниями</p>
              <p className='text-2xl text-muted-foreground'>
                в 2022 начали работать с большими компаниями
              </p>
            </div>
          </CardContent>
        </Card>
      </div>
    </section>
  );
}
