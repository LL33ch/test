import AboutUs from '@/components/about-us';
import Header from '@/components/header';
import OurTeam from '@/components/our-team';

import Image from 'next/image';

export default function Home() {
  return (
    <>
      <Header />
      <main className=' space-y-28'>
        <section className='mt-20 pt-10'>
          <div className='max-w-[1500px] mx-auto'>
            <div className='grid grid-cols-2 items-start'>
              <div className='grid space-y-5 mt-32'>
                <span className='text-4xl text-primary'>Быстрая, надежная, качественная ❤️️</span>
                <span className='text-4xl'>Студия онлайн разработки 🔥 </span>
                <span className='text-2xl text-muted-foreground'>
                  Команда с лучшими веб разработчиками в СНГ 🚀
                </span>
              </div>
              <Image src='/image.png' width={800} height={800} alt='image' />
            </div>
          </div>
          <Image src='/Arrow 1.svg' width={10} height={10} alt='image' className='mx-auto' />
        </section>
        <OurTeam />
        <AboutUs />
      </main>
    </>
  );
}
