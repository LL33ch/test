import Header from '@/components/header';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Avatar, AvatarImage } from '@/components/ui/avatar';

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
        <section className='max-w-[1500px] mx-auto'>
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
                  <p className='text-muted-foreground text-center'>
                    founder\\\ full-stack developer
                  </p>
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
        <section className='bg-gradient-to-t from-[#0500FF33] to-transparent'>
          <div className='max-w-[1500px] mx-auto pb-40'>
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
      </main>
    </>
  );
}
