import Link from 'next/link';

export default function Header() {
  return (
    <header className='p-5 text-2xl justify-between border-b border-primary px-10'>
      <div className='max-w-[1500px] mx-auto grid grid-cols-2'>
        <Link href='/'>CODE BRANCH</Link>
        <div className='text-xl ms-auto space-x-14'>
          <Link href='/'>команда</Link>
          <Link href='/'>о нас</Link>
        </div>
      </div>
    </header>
  );
}
